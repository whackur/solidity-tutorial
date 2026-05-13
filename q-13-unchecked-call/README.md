# Q-13. Unchecked call — silent payout failure

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-13-unchecked-call.md`](../../solidity-tutorial-lecture/docs/challenges/q-13-unchecked-call.md)
> **Lecture (Korean)**: [PPT 4-1 §4](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A single `UnsafePayout` escrow is deployed. Its `payout(to)` advances
the per-user state (`escrow = 0`, `paidOut = true`) *and* ignores the
boolean return of the low-level call. If `to` reverts on receive, the
funds stay in the contract, but the user is still recorded as "paid out"
— a silent failure.

The contract exposes a helper `RevertOnReceive` (`trap`) so you don't
need to deploy your own reverting receiver.

## Goal

Make `UnsafePayout.isSolved(yourAddress)` return `true`. That requires:

- `paidOut[you] == true` — payout function was called.
- `stranded[you] > 0` — your payout target rejected ETH, yet you got
  "paid".

## Contract surface

```solidity
function deposit() external payable;                  // escrow[you] += msg.value
function payout(address payable to) external;        // BUG: ignores call return
function trap() external view returns (RevertOnReceive);
function escrow(address) external view returns (uint256);
function paidOut(address) external view returns (bool);
function stranded(address) external view returns (uint256);
function isSolved(address user) external view returns (bool);
```

## The bug under attack

```solidity
function payout(address payable to) external {
    uint256 amount = escrow[msg.sender];
    require(amount > 0, "no escrow");
    escrow[msg.sender] = 0;
    paidOut[msg.sender] = true;
    (bool ok,) = to.call{value: amount}("");
    // BUG: bool ignored. In a real bug there'd be no `if (!ok)` block.
    if (!ok) stranded[msg.sender] += amount;   // tutorial-grade tracking
}
```

In production this often shows up as
`recipient.call{value: amount}("");` — the literal "fire-and-forget"
mistake.

## UI call sequence

1. `escrow.deposit{value: 1 ether}()` — fills your escrow slot.
2. `escrow.payout(escrow.trap())` — payout to a contract that reverts
   on receive. The function does not revert; state advances anyway.
3. `escrow.isSolved(you)` → `true`.

## Concepts exercised

- **Low-level `call` returns `(bool, bytes)` — both must be checked**.
  Solidity does not auto-revert on a returned `false` (unlike a
  `try/catch` over a typed call).
- **High-level call vs low-level call**: typed external calls
  (`IFoo(addr).bar()`) revert on callee revert by default. Only
  `addr.call(...)` requires manual handling.
- **The "fire-and-forget" anti-pattern** — `to.send(amount)` and
  `to.transfer(amount)` partially fix this (revert on failure for
  `transfer`, return false for `send`) but have their own problems
  (2300-gas limit breaks 4337 wallets).
- **Effects-before-call ordering is correct here** — the bug is *not*
  reentrancy, it's failure-tolerance.

## Defending it

```solidity
(bool ok,) = to.call{value: amount}("");
require(ok, "transfer failed");
```

Better: use OZ `Address.sendValue(to, amount)` which reverts on failure
and propagates revert data.

For ERC-20: never trust the boolean either — many tokens (USDT) do not
return one. Use `SafeERC20.safeTransfer`.
