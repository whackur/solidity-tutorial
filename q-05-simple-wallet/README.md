# Q-05. Q05SimpleWallet — ETH + ERC-20 deposit / withdraw

> **Difficulty**: Beginner ⭐⭐

A single `Q05SimpleWallet` (and a shared `Q05MockERC20` with public `mint`) is
deployed. Every user has their own ETH and per-token balance slots keyed
by `msg.sender`. You complete the challenge by walking ETH and ERC-20
through deposit → withdraw on your own address.

## Goal

Make `Q05SimpleWallet.isSolved(yourAddress)` return `true`. That requires
all four flags to be set for *your* address:

- `depositedEth[you]` — you sent value to `depositEth()` or to the wallet's `receive()`.
- `withdrewEth[you]` — you successfully called `withdrawEth(amount > 0)`.
- `depositedErc20[you]` — you called `depositErc20(token, amount > 0)`.
- `withdrewErc20[you]` — you successfully called `withdrawErc20(token, amount > 0)`.

## Contract surface

```solidity
// Q05SimpleWallet
function depositEth() external payable;
function withdrawEth(uint256 amount) external;
function depositErc20(address token, uint256 amount) external;       // pull via transferFrom
function withdrawErc20(address token, uint256 amount) external;
receive() external payable;                                          // also triggers depositEth path

function ethBalanceOf(address user) external view returns (uint256);
function erc20BalanceOf(address user, address token) external view returns (uint256);
function isSolved(address user) external view returns (bool);

// Q05MockERC20 (public faucet)
function mint(address to, uint256 amount) external;
```

## What you can interact with

- ETH deposit/withdraw paths and ERC-20 deposit/withdraw paths.
- A public token faucet is available for experimentation.

## Hints

- There is more than one way to reach the ETH deposit path.
- The ERC-20 flow follows the usual approve-then-pull pattern.
- Any non-zero round trip that leaves the per-user flags set should be enough.

## Constraints

- Keep the actions tied to your own wallet state.
- The exact amounts are not the lesson; the routing and accounting are.

## Concepts exercised

- ETH-bearing transactions: `payable`, `msg.value`, `receive()`.
- ERC-20 *pull pattern*: approve → `transferFrom`. The wallet never holds
  your tokens unless you've first granted allowance.
- Per-user balance tables in a single contract (`mapping(address => …)`)
  — the most basic multi-tenant accounting pattern.
- `msg.sender.call{value: x}("")` for ETH withdrawal and why `ok` must be
  checked.
