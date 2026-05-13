# Q-05. SimpleWallet — ETH + ERC-20 deposit / withdraw

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-05-simple-wallet.md`](../../solidity-tutorial-lecture/docs/challenges/q-05-simple-wallet.md)
> **Lecture (Korean)**: [PPT 2-4](../../solidity-tutorial-lecture/docs/02-dev-environment/2-4-wallet-game.md)

A single `SimpleWallet` (and a shared `MockERC20` with public `mint`) is
deployed. Every user has their own ETH and per-token balance slots keyed
by `msg.sender`. You complete the challenge by walking ETH and ERC-20
through deposit → withdraw on your own address.

## Goal

Make `SimpleWallet.isSolved(yourAddress)` return `true`. That requires
all four flags to be set for *your* address:

- `depositedEth[you]` — you sent value to `depositEth()` or to the wallet's `receive()`.
- `withdrewEth[you]` — you successfully called `withdrawEth(amount > 0)`.
- `depositedErc20[you]` — you called `depositErc20(token, amount > 0)`.
- `withdrewErc20[you]` — you successfully called `withdrawErc20(token, amount > 0)`.

## Contract surface

```solidity
// SimpleWallet
function depositEth() external payable;
function withdrawEth(uint256 amount) external;
function depositErc20(address token, uint256 amount) external;       // pull via transferFrom
function withdrawErc20(address token, uint256 amount) external;
receive() external payable;                                          // also triggers depositEth path

function ethBalanceOf(address user) external view returns (uint256);
function erc20BalanceOf(address user, address token) external view returns (uint256);
function isSolved(address user) external view returns (bool);

// MockERC20 (public faucet)
function mint(address to, uint256 amount) external;
```

## UI call sequence

1. `wallet.depositEth()` from your wallet with some value (e.g., 1 ETH).
   - Or just send a plain transfer to the wallet — `receive()` routes it
     through the same path.
2. `wallet.withdrawEth(amount)` with `amount > 0` and `amount <= ethBalance`.
3. `token.mint(you, X)` to get yourself some MCK to play with.
4. `token.approve(wallet, X)` so the wallet can pull from you.
5. `wallet.depositErc20(token, X)`.
6. `wallet.withdrawErc20(token, X / 2)` (or any non-zero amount you own).
7. Read `wallet.isSolved(you)` → `true`.

## Concepts exercised

- ETH-bearing transactions: `payable`, `msg.value`, `receive()`.
- ERC-20 *pull pattern*: approve → `transferFrom`. The wallet never holds
  your tokens unless you've first granted allowance.
- Per-user balance tables in a single contract (`mapping(address => …)`)
  — the most basic multi-tenant accounting pattern.
- `msg.sender.call{value: x}("")` for ETH withdrawal and why `ok` must be
  checked.
