# Q-04 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q04DelegatecallLab` address. `USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | — | deploys `(Q04DelegateCaller, Q04DelegateLogic)` for USER; event `InstanceCreated(USER, caller, logic)` |
| 2 | view | `LAB` | `callerOf(USER)` / `logicOf(USER)` | — | snapshot the two addresses |
| 3 | `USER` | `caller` | `setVarsViaCall(Q04DelegateLogic,uint256)` | `(logic, 42)` | normal call → writes to `logic` storage slot 0 |
| 4 | view | `logic` | `number()` | — | `42` |
| 5 | view | `caller` | `number()` | — | `0` (unchanged — call wrote to logic, not caller) |
| 6 | `USER` | `caller` | `setVarsViaDelegatecall(address,uint256)` | `(logic, 99)` | delegatecall → executes logic code in caller's storage |
| 7 | view | `caller` | `number()` | — | `99` |
| 8 | view | `logic` | `number()` | — | still `42` |
| 9 | view | `caller` | `sender()` | — | `USER` (delegatecall preserves outer msg.sender) |
| 10 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Notes

- Steps 3 and 6 can also be sent with `value > 0` to demonstrate that
  `msg.value` is forwarded transparently by `call`/`delegatecall`.
- `createInstance()` reverts with `"already created"` if USER already has
  a pair. The test verifies this.
- Test harness simulates Alice + Bob in parallel and asserts distinct
  caller/logic addresses per user.
