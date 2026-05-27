# Q-14. DoS by revert — lock the throne with a reverting receiver

> **Difficulty**: Beginner ⭐⭐

A `Q14DosLab` is deployed. Each user calls `createInstance()` to mint a
personal `(Q14KingOfHill, Q14RevertKing)` pair. `Q14KingOfHill.bid()` refunds the
previous king via `call` and *requires the refund to succeed*. The
`Q14RevertKing` reverts on every receive — once it becomes king, the throne
is permanently locked because no future bidder can refund it.

## Goal

Make `Q14DosLab.isSolved(yourAddress)` return `true`: the current king of
your personal `Q14KingOfHill` is your personal `Q14RevertKing`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address king, address attacker);
function kingOf(address user) external view returns (Q14KingOfHill);
function attackerOf(address user) external view returns (Q14RevertKing);
function isSolved(address user) external view returns (bool);

// Q14KingOfHill (per user — DO NOT FIX)
function bid() external payable;             // require(ok) on push refund
function currentKing() external view returns (address);
function currentBid() external view returns (uint256);

// Q14RevertKing (per user, owner = you)
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

## What you can interact with

- A king-of-the-hill contract and a reverting receiver tied to your own instance.

## Hints

- The vulnerability appears when a refund is mandatory for progress.
- A receiver that always reverts can freeze the game for everyone else.
- Your goal is to understand the availability impact of push-based refunds.

## Constraints

- Use your own pair of contracts.
- The lesson is the denial-of-service shape, not a specific bid amount.

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
