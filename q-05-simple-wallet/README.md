# Q-05. SimpleWallet — ETH + ERC-20 deposit / withdraw

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-05-simple-wallet.md`](../../solidity-tutorial-lecture/docs/challenges/q-05-simple-wallet.md)
> **Lecture (Korean)**: [PPT 2-4](../../solidity-tutorial-lecture/docs/02-dev-environment/2-4-wallet-game.md)
> **Reference source**: [`../simple-wallet/src/SimpleWallet.sol`](../simple-wallet/src/SimpleWallet.sol)

## Scenario

`SimpleWallet` tracks per-address ETH and ERC-20 balances in mappings. `depositErc20` pulls tokens with `transferFrom`, so the wallet must be **approved** before the call.

## What to implement

```solidity
function depositAll(SimpleWallet w, IERC20 token) external payable;
function withdrawHalfTokens(SimpleWallet w, IERC20 token, uint256 originalAmount) external;
```

- `depositAll` — forward all `msg.value` plus the contract's full token balance into the wallet (in the correct order: approve, then deposit).
- `withdrawHalfTokens` — withdraw half of `originalAmount` tokens back to this contract.

## Hints

- `w.depositEth{value: msg.value}();`
- Approve **first**, then `w.depositErc20(address(token), bal);`.
- Token balance: `IERC20(token).balanceOf(address(this))`.

## Grading

```bash
forge test -vv
```

- `test_DepositMovesEth` — wallet holds the ETH.
- `test_DepositMovesTokens` — wallet holds tokens; solution holds none.
- `test_WithdrawHalfTokens` — after withdrawing half, both sides hold 50/50.
