# Q-05 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`W` = deployed `SimpleWallet`. `T` = deployed `MockERC20`. `USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Value | Notes |
|---|---|---|---|---|---|---|
| 1 | `USER` | `W` | `depositEth()` | — | `1 ether` | sets `depositedEth[USER]`, `ethBalanceOf(USER) == 1e18` |
| 2 | `USER` | `W` | `withdrawEth(uint256)` | `5e17` (0.5 ETH) | 0 | sets `withdrewEth[USER]` |
| 3 | `USER` | `T` | `mint(address,uint256)` | `(USER, 100e18)` | 0 | self-faucet |
| 4 | `USER` | `T` | `approve(address,uint256)` | `(W, 100e18)` | 0 | grants pull allowance |
| 5 | `USER` | `W` | `depositErc20(address,uint256)` | `(T, 100e18)` | 0 | sets `depositedErc20[USER]`; wallet pulls via `transferFrom` |
| 6 | `USER` | `W` | `withdrawErc20(address,uint256)` | `(T, 50e18)` | 0 | sets `withdrewErc20[USER]` |
| 7 | view | `W` | `isSolved(USER)` | — | — | `true` |

## Notes

- Step 1 can be replaced by a plain ETH transfer to the wallet (empty
  calldata + value) — `receive()` routes it through `depositEth`.
- Amounts must be `> 0`; the wallet rejects zero deposits/withdrawals.
- Per-user accounting is independent: another user solving the same
  challenge does not change `ethBalanceOf(USER)` or any solve flag.
- The MockERC20 has a public `mint`; this is *only acceptable for
  tutorials*. Production tokens should not expose this.
