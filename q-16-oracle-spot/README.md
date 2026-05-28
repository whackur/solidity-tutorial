# Q-16. Oracle manipulation — spot-price lender risk

> **Difficulty**: Intermediate ⭐⭐⭐

A pre-funded `Q16OracleLab` is deployed. Each user gets a personal `(Q16MockToken, Q16SimplePool, Q16SpotLender)` triple plus test tokens. The lender values collateral using the pool's *spot price* — a single read that can be distorted within the same transaction.

## Goal

Make `Q16OracleLab.isSolved(yourAddress)` return `true` by exploiting only *your* lender instance.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address token, address pool, address lender);
function tokenOf(address user) external view returns (Q16MockToken);
function poolOf(address user) external view returns (Q16SimplePool);
function lenderOf(address user) external view returns (Q16SpotLender);
function isSolved(address user) external view returns (bool);
uint256 public constant POOL_ETH_SEED = 1 ether;
uint256 public constant POOL_TKN_SEED = 100e18;
uint256 public constant LENDER_SEED = 5 ether;
uint256 public constant USER_TKN_FAUCET = 100e18;

// Q16SimplePool (x*y=k, no fees — per user)
function swapEthForToken() external payable returns (uint256 tokenOut);
function swapTokenForEth(uint256 amountIn) external returns (uint256 ethOut);
function spotPriceEthPerToken() external view returns (uint256);   // wei per 1e18 TKN

// Q16SpotLender (per user — DO NOT FIX)
function borrow(uint256 collateral) external returns (uint256 loan);
function collateralOf(address) external view returns (uint256);

// Q16MockToken (per user)
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

The exploit shape is not about a specific magic amount. It is about making a spot-price read observe a temporary market state that does not represent fair collateral value.

## What you can interact with

- A pool, a token, and a lender inside your own instance.
- The lender values collateral using the pool's current spot price.

## Hints

- The key weakness is reading a manipulable price at the exact time of borrowing.
- A same-transaction market action can temporarily distort the pool price.
- You do not need a perfect market model to understand the exploit shape.

## Constraints

- Keep the attack inside your own instance.
- This is about oracle design, not a special token bug.

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
