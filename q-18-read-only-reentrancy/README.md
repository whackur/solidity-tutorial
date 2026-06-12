# Q-18. Read-only reentrancy — fool a price consumer with stale state

> **Difficulty**: Intermediate ⭐⭐⭐

A `Q18ShareVault`'s `withdraw()` sends ETH out *before* updating `totalShares`. The `sharePrice()` view function is correct in isolation, but during the re-entry window it can report a temporarily inconsistent value. A separate `Q18PriceConsumer` trusts that view as if it were a stable oracle.

## Goal

Make `Q18ReadOnlyLab.isSolved(yourAddress)` return `true` by demonstrating that a trusted view can be stale during a callback window.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address consumer, address attacker);
function vaultOf(address) external view returns (Q18ShareVault);
function consumerOf(address) external view returns (Q18PriceConsumer);
function attackerOf(address) external view returns (Q18ReadOnlyAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED_DEPOSIT = 0.001 ether;

// Q18ShareVault (per user — DO NOT FIX)
function deposit() external payable;
function withdraw(uint256 sh) external;
function sharePrice() external view returns (uint256);
function shares(address) external view returns (uint256);
function totalShares() external view returns (uint256);

// Q18PriceConsumer (per user)
function mintCredits(address recipient, uint256 weiAmount) external;
function credits(address) external view returns (uint256);

// Q18ReadOnlyAttacker (per user, owner = you)
function attack() external payable;    // onlyOwner
function drain() external;             // onlyOwner
```

## The bug under attack

```solidity
function withdraw(uint256 sh) external {
    require(shares[msg.sender] >= sh, "insufficient");
    uint256 amount = (sh * address(this).balance) / totalShares;
    shares[msg.sender] -= sh;
    (bool ok,) = msg.sender.call{value: amount}("");  // ← external call
    require(ok, "send failed");
    totalShares -= sh;                                  // ← AFTER call
}

function sharePrice() external view returns (uint256) {
    if (totalShares == 0) return 1 ether;
    return (address(this).balance * 1e18) / totalShares;
}
```

After the external call changes ETH balance but before all accounting catches up, `sharePrice()` can expose a stale value. A `nonReentrant` modifier on the mutator alone does **not** necessarily protect an external consumer that trusts a view function.

The consumer bug is trusting a momentary view result as a reliable oracle input.

## What you can interact with

- A share vault, a price consumer, and an attacker contract.
- The consumer reads a view function that can become stale during reentry.

## Hints

- The exploit happens without mutating the vault during the callback.
- Focus on the brief window where the price view sees an inconsistent state.
- If a consumer trusts a view too much, it can be fooled by timing.

## Constraints

- Keep the solution inside your own lab instance.
- The lesson is read-only inconsistency, not direct storage tampering.

## Concepts exercised

- **Read-only reentrancy**: re-entering *only* a view function during
  a callback. No state mutation happens during re-entry, so naive
  `nonReentrant` modifiers on mutators don't help.
- **Cross-contract trust on a spot view**: any contract treating a
  callee's `view` as an oracle inherits its consistency assumptions.
- **The Curve/Convex 2022 exploit shape**: the same `get_virtual_price`
  view of a Curve pool returned bad values during `remove_liquidity`.
  Several protocols using it as a price oracle were drained.

## Defending it

Two complementary fixes:

1. **CEI**: update the invariant-defining state *before* every external
   call.

   ```solidity
   function withdraw(uint256 sh) external {
       require(shares[msg.sender] >= sh, "insufficient");
       uint256 amount = (sh * address(this).balance) / totalShares;
       shares[msg.sender] -= sh;
       totalShares -= sh;                                 // effects first
       (bool ok,) = msg.sender.call{value: amount}("");
       require(ok, "send failed");
   }
   ```

2. **Read-only reentrancy guard**: protect the view function itself
   with a flag flipped by the mutator.

   ```solidity
   uint256 private _entered;
   modifier nonReentrantView() {
       require(_entered == 0, "read-only reentry");
       _;
   }
   function withdraw(uint256 sh) external {
       _entered = 1;
       ...
       _entered = 0;
   }
   function sharePrice() external view nonReentrantView returns (uint256) { ... }
   ```

   This is exactly OpenZeppelin's `ReentrancyGuardTransient` +
   `_reentrancyGuardEntered()` pattern for view callers.
