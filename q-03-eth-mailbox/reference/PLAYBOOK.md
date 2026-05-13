# Q-03 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`MB` = deployed `EthMailbox` address. `USER` = user's EOA.

## Steps

| # | From | To | Calldata | Value | Lands in | Notes |
|---|---|---|---|---|---|---|
| 1 | `USER` | `MB` | (empty `0x`) | `> 0` | `receive()` | sets `hitReceive[USER]`, `lastTrigger = Receive` |
| 2 | `USER` | `MB` | `setFallbackTag(bytes32)` encoded — e.g. `0x<sel>...<tag>` | any | `fallback()` | sets `hitFallback[USER]`, decodes 32-byte tag into `lastTag[USER]` |
| 3 | `USER` | `MB` | `receivePayable(bytes32 tag)` | `> 0` | named function | sets `hitReceivePayable[USER]`, also writes `lastTag` |
| 4 | anyone | `MB` | `isSolved(USER)` (view) | — | — | returns `true` |

## Notes

- The selector `setFallbackTag(bytes32)` is unknown to the contract's
  function table (the only declared external function is `receivePayable`),
  so the EVM dispatches to `fallback()`.
- `countFallback()` is another unknown selector that bumps
  `fallbackHits[USER]` — useful if instructor wants to demo idempotency.
- Step 3 also overwrites `lastTag[USER]` with the tag in the call,
  which is expected behavior — `isSolved` does not depend on which tag.
- Test harness simulates Alice + Bob in parallel via `vm.prank`.
