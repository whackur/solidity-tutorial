# Q-18. Read-only reentrancy — fool a price consumer with stale state

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-18-read-only-reentrancy.md`](../../solidity-tutorial-lecture/docs/challenges/q-18-read-only-reentrancy.md)
> **Lecture (Korean)**: [PPT 4-1 §2-2](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A `ShareVault`'s `withdraw()` sends ETH out *before* updating
`totalShares`. The `sharePrice()` view function is correct in isolation,
but during that re-entry window it returns a temporarily-deflated price.
A separate `PriceConsumer` contract reads `sharePrice()` and mints
credits inversely proportional to it. By calling the consumer *from
inside the vault's withdraw callback*, an attacker mints far more
credits than the honest price would justify — without ever mutating
the vault's state from outside.

## Goal

Make `ReadOnlyLab.isSolved(yourAddress)` return `true`:
`consumer.credits(attackerOf(you)) >= CREDIT_THRESHOLD (5e18)`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address consumer, address attacker);
function vaultOf(address) external view returns (ShareVault);
function consumerOf(address) external view returns (PriceConsumer);
function attackerOf(address) external view returns (ReadOnlyAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED_DEPOSIT = 0.1 ether;
uint256 public constant CREDIT_THRESHOLD = 5e18;

// ShareVault (per user — DO NOT FIX)
function deposit() external payable;
function withdraw(uint256 sh) external;
function sharePrice() external view returns (uint256);
function shares(address) external view returns (uint256);
function totalShares() external view returns (uint256);

// PriceConsumer (per user)
function mintCredits(address recipient, uint256 weiAmount) external;
function credits(address) external view returns (uint256);

// ReadOnlyAttacker (per user, owner = you)
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

After `msg.sender.call` lowers `address(this).balance` but before
`totalShares -= sh` runs, `sharePrice()` returns a stale, deflated value.
A `nonReentrant` modifier on `withdraw` alone does **not** save the
consumer — the consumer is being called inside the same reentry window
but `sharePrice` is a *view*, not a mutator.

```solidity
function mintCredits(address recipient, uint256 weiAmount) external {
    uint256 price = vault.sharePrice();                // ← reads stale price
    require(price > 0, "bad price");
    credits[recipient] += (weiAmount * 1e18) / price;  // ← inverse: low price → high credits
}
```

## UI call sequence

1. `lab.createInstance()` — deploys (vault, consumer, attacker). Lab
   pre-deposits `0.1 ETH` as "innocent depositor".
2. `attacker.attack{value: 0.9 ether}()`:
   - Attacker deposits `0.9 ETH` → vault: `1 ETH`, `totalShares: 1e18`.
   - Attacker calls `withdraw(0.9e18)`. Vault sends `0.9 ETH` to attacker.
     During attacker's `receive()`, vault balance is `0.1 ETH` but
     `totalShares` is still `1e18` → `sharePrice = 0.1e18` (10× lower).
   - Attacker calls `consumer.mintCredits(attacker, 1 ether)` → mints
     `~10e18` credits.
   - `withdraw` resumes and sets `totalShares -= 0.9e18 → 0.1e18`.
3. `lab.isSolved(you)` → `true`.

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
