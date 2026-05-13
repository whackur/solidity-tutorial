# Q-02 — Instructor Playbook

> Ordered transactions a user's web UI would send to reach `isSolved(user) == true`.
> Kept out of student-facing materials.

`EE` = deployed `EventsAndErrors` address. `USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `EE` | `failWithRequire(uint256)` | `0` | reverts with `Error(string)`; observe selector `0x08c379a0` |
| 2 | `USER` | `EE` | `reportErrorSelector(bytes4)` | `0x08c379a0` | sets `solvedError[USER]` |
| 3 | `USER` | `EE` | `failWithAssert(bool)` | `false` | reverts with `Panic(uint256)`; observe selector `0x4e487b71` |
| 4 | `USER` | `EE` | `reportPanicSelector(bytes4)` | `0x4e487b71` | sets `solvedPanic[USER]` |
| 5 | `USER` | `EE` | `failWithCustomError(uint256,uint256)` | `1, 2` | reverts with custom `InsufficientBalance(1,2)` |
| 6 | `USER` | `EE` | `reportCustomSelector(bytes4)` | `bytes4(keccak256("InsufficientBalance(uint256,uint256)"))` | sets `solvedCustom[USER]` |
| 7 | anyone | `EE` | `isSolved(address)` (view) | `USER` | `true` |

## Notes

- The custom-error selector can be precomputed off-chain
  (`cast sig 'InsufficientBalance(uint256,uint256)'`) or copied from the
  raw revert payload of step 5.
- Test harness in `test/Challenge.t.sol` repeats this for `alice` and
  `bob` in parallel under `vm.prank` to verify per-user isolation.
