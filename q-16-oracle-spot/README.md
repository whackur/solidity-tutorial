# Q-16. Oracle manipulation — drain a spot-price lender

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-16-oracle-spot.md`](../../solidity-tutorial-lecture/docs/challenges/q-16-oracle-spot.md)
> **Lecture (Korean)**: [PPT 4-1 §6, 6-2](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A pre-funded `OracleLab` is deployed. Each user calls `createInstance()`
to get a personal `(MockToken, SimplePool, SpotLender)` triple plus a
100 TKN faucet. The lender values TKN collateral using the pool's *spot
price* — a single read that the user controls in the same tx via a
swap. Push the spot price up, borrow far more ETH than your collateral
is actually worth, drain the lender.

## Goal

Make `OracleLab.isSolved(yourAddress)` return `true`: drain *your*
personal `SpotLender` to `0 ETH`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address token, address pool, address lender);
function tokenOf(address user) external view returns (MockToken);
function poolOf(address user) external view returns (SimplePool);
function lenderOf(address user) external view returns (SpotLender);
function isSolved(address user) external view returns (bool);
uint256 public constant POOL_ETH_SEED = 1 ether;
uint256 public constant POOL_TKN_SEED = 100e18;
uint256 public constant LENDER_SEED = 5 ether;
uint256 public constant USER_TKN_FAUCET = 100e18;

// SimplePool (x*y=k, no fees — per user)
function swapEthForToken() external payable returns (uint256 tokenOut);
function swapTokenForEth(uint256 amountIn) external returns (uint256 ethOut);
function spotPriceEthPerToken() external view returns (uint256);   // wei per 1e18 TKN

// SpotLender (per user — DO NOT FIX)
function borrow(uint256 collateral) external returns (uint256 loan);
function collateralOf(address) external view returns (uint256);

// MockToken (per user)
function approve(address spender, uint256 amount) external returns (bool);
function balanceOf(address) external view returns (uint256);
```

## The bug under attack

```solidity
function borrow(uint256 collateral) external returns (uint256 loan) {
    require(collateral > 0, "no collateral");
    token.transferFrom(msg.sender, address(this), collateral);
    collateralOf[msg.sender] += collateral;
    // BUG: spot price read at this exact moment. Manipulable in-tx via swap.
    uint256 price = pool.spotPriceEthPerToken();
    loan = (collateral * price) / 1e18;
    if (loan > address(this).balance) loan = address(this).balance;
    ...
}
```

Initial reserves give spot price ≈ `0.01 ETH / TKN`. A `3 ETH` swap
into the pool raises the spot price to roughly `0.16 ETH / TKN` —
a 16× distortion. With `40 TKN` of collateral that distorted price
quotes `6.4 ETH`, capped at the lender's `5 ETH` liquidity — the
entire treasury walks out.

## UI call sequence

1. `lab.createInstance()` — deploys your `(token, pool, lender)` and
   faucets 100 TKN to your wallet.
2. `pool.swapEthForToken{value: 3 ether}()` — push the spot price up.
3. `token.approve(lender, type(uint256).max)`.
4. `lender.borrow(40e18)` — borrow against inflated collateral value.
5. `lab.isSolved(you)` → `true`.

## Concepts exercised

- **Spot oracles are atomic-tx attackable**. The price at any single
  block is moved by anyone with enough capital — and with flash loans
  that capital is rentable for the duration of one tx.
- **Why the 2020-2022 wave of DeFi exploits looked like this**: Harvest,
  Cheese Bank, MakerDAO oracle race, Cream Finance, Mango Markets. The
  shape is always "single pool, single read, atomic manipulation".
- **TWAP** (time-weighted average price): aggregates spot over a window,
  forcing an attacker to *sustain* the manipulation over many blocks —
  expensive and visible. Uniswap V2 / V3 ship the primitive.
- **Off-chain push oracles** (Chainlink, Pyth): a committee of nodes
  signs prices off-chain and posts them, decoupling price from any
  single on-chain venue.

## Defending it

Cheap fix — use Chainlink:

```solidity
AggregatorV3Interface public immutable feed;

uint256 price;
(, int256 answer,,,) = feed.latestRoundData();
require(answer > 0, "bad feed");
price = uint256(answer) * 1e18 / 10**feed.decimals();
```

Self-hosted fix — TWAP:

```solidity
// Uniswap V2 cumulative-price oracle (sketch)
uint256 priceCumulativeNow = pool.price0CumulativeLast() + ...;
uint256 twap = (priceCumulativeNow - priceCumulativeStored) / elapsed;
require(elapsed >= TWAP_WINDOW, "too soon");
```

Defense in depth — combine on-chain TWAP with off-chain Chainlink and
sanity-bounds (`max deviation`, `staleness check`).
