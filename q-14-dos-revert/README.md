# Q-14. DoS by revert — lock the throne with a reverting receiver

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-14-dos-revert.md`](../../solidity-tutorial-lecture/docs/challenges/q-14-dos-revert.md)
> **Lecture (Korean)**: [PPT 4-1 §9](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A `DosLab` is deployed. Each user calls `createInstance()` to mint a
personal `(KingOfHill, RevertKing)` pair. `KingOfHill.bid()` refunds the
previous king via `call` and *requires the refund to succeed*. The
`RevertKing` reverts on every receive — once it becomes king, the throne
is permanently locked because no future bidder can refund it.

## Goal

Make `DosLab.isSolved(yourAddress)` return `true`: the current king of
your personal `KingOfHill` is your personal `RevertKing`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address king, address attacker);
function kingOf(address user) external view returns (KingOfHill);
function attackerOf(address user) external view returns (RevertKing);
function isSolved(address user) external view returns (bool);

// KingOfHill (per user — DO NOT FIX)
function bid() external payable;             // require(ok) on push refund
function currentKing() external view returns (address);
function currentBid() external view returns (uint256);

// RevertKing (per user, owner = you)
function takeThrone() external payable;       // onlyOwner, forwards bid
function owner() external view returns (address);
// receive() / fallback() always revert
```

## The bug under attack

```solidity
function bid() external payable {
    require(msg.value > currentBid, "bid too low");
    if (currentKing != address(0)) {
        (bool ok,) = currentKing.call{value: currentBid}("");
        require(ok, "refund failed");      // ← single point of DoS
    }
    currentKing = msg.sender;
    currentBid = msg.value;
}
```

When the previous king is a contract that reverts on receive, the
refund call always fails → the entire `bid()` tx reverts → the throne
sticks with the reverter forever.

## UI call sequence

1. `lab.createInstance()` — deploys (KingOfHill, RevertKing) for you.
2. `kingOf(you).bid{value: 0.01 ether}()` — from your EOA. You're king.
3. `attackerOf(you).takeThrone{value: 0.02 ether}()` — forwards a bid
   from RevertKing. The refund to *you* succeeds (you're an EOA), so
   RevertKing dethrones you and takes the seat.
4. `lab.isSolved(you)` → `true`.
5. (Optional demo) Any third-party `bid{value: 1 ether}()` now reverts
   with `"refund failed"` — proves the lock.

## Concepts exercised

- **Push vs pull payments**. `bid()` *pushes* the refund — making any
  unhappy recipient an availability hazard for the whole protocol.
  The pull pattern would store refunds in a `pendingRefunds[user]`
  mapping and let the previous king `withdraw()` themselves.
- **Reverting receive() as an attack surface** — not just a "broken
  fallback", it's a DoS primitive.
- **Auction / lottery / leaderboard contracts** are the canonical
  victims. King-of-the-Hill is the textbook reduction.

## Defending it

Pull-payment refunds:

```solidity
mapping(address => uint256) public refunds;

function bid() external payable {
    require(msg.value > currentBid, "bid too low");
    if (currentKing != address(0)) {
        refunds[currentKing] += currentBid;   // accrue, don't push
    }
    currentKing = msg.sender;
    currentBid = msg.value;
}

function claimRefund() external {
    uint256 amount = refunds[msg.sender];
    refunds[msg.sender] = 0;
    (bool ok,) = msg.sender.call{value: amount}("");
    require(ok, "withdraw failed");
}
```

Or use OZ `PullPayment` / `Escrow`.
