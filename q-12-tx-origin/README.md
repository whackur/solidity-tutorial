# Q-12. tx.origin — drain your vault through a phisher lure

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-12-tx-origin.md`](../../solidity-tutorial-lecture/docs/challenges/q-12-tx-origin.md)
> **Lecture (Korean)**: [PPT 4-1 §3, 3-2](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A pre-funded `TxOriginLab` is deployed. Each user calls `createInstance()`
once to get a personal `(TxOriginVault, Phisher)` pair seeded with
`5 ETH`. The vault's `transferTo` authenticates with `tx.origin == owner`
instead of `msg.sender == owner` — so any contract the user calls inside
the same tx can drain the vault on their behalf. The phisher is exactly
that lure.

## Goal

Make `TxOriginLab.isSolved(yourAddress)` return `true`. That requires:

- `address(vaultOf(you)).balance == 0` — drained.
- `phisherOf(you).airdropClaimed() == true` — drained via the phisher.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address phisher);
function vaultOf(address user) external view returns (TxOriginVault);
function phisherOf(address user) external view returns (Phisher);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 5 ether;

// TxOriginVault (your personal instance — DO NOT FIX)
function transferTo(address payable to, uint256 amount) external;
function owner() external view returns (address);

// Phisher (your personal instance, beneficiary = you)
function claimFreeAirdrop() external;
function airdropClaimed() external view returns (bool);
```

## The bug under attack

```solidity
function transferTo(address payable to, uint256 amount) external {
    // BUG: tx.origin authentication trusts the originating EOA,
    //      regardless of which intermediate contract called us.
    require(tx.origin == owner, "not owner");
    (bool ok,) = to.call{value: amount}("");
    require(ok, "send failed");
}
```

```solidity
function claimFreeAirdrop() external {
    airdropClaimed = true;
    vault.transferTo(beneficiary, address(vault).balance);
}
```

The user clicks "Claim free airdrop" → their wallet sends a tx →
phisher calls `vault.transferTo(beneficiary, balance)` → vault checks
`tx.origin == owner` (true, because the user *is* the owner and they
initiated the tx) → drain succeeds.

In a real attack `beneficiary` is the phisher's address. For tutorial
grading we wire `beneficiary = msg.sender` so the drained ETH returns
to the user and `isSolved` can verify the path.

## UI call sequence

1. `lab.createInstance()` — deploys vault (5 ETH) + phisher.
2. `phisherOf(you).claimFreeAirdrop()` — lure pulls all 5 ETH back to you.
3. `lab.isSolved(you)` → `true`.

## Concepts exercised

- **`tx.origin` vs `msg.sender`**: `tx.origin` is the bottom of the call
  stack (the EOA that signed the tx). `msg.sender` is the immediate
  caller. Authenticating with `tx.origin` lets any contract the user
  touches act on their behalf.
- **Phishing surface**: a wallet popup says "approve this transaction"
  — users see only the top-level call. Anything that contract does
  inside the same tx still satisfies a `tx.origin` check.
- **The narrow legitimate use of `tx.origin`**: EIP-3074-style sponsored
  transactions, anti-flashbot guards `tx.origin == msg.sender` (blocks
  contracts entirely). Even those are migrating to EIP-7702 / 4337.

## Defending it

```solidity
function transferTo(address payable to, uint256 amount) external {
    require(msg.sender == owner, "not owner");   // ← msg.sender, not tx.origin
    (bool ok,) = to.call{value: amount}("");
    require(ok, "send failed");
}
```

EOA-only guard (different intent, also not tx.origin-based):
`require(msg.sender == tx.origin, "no contracts")` — blocks contracts
entirely, including ERC-4337 wallets.
