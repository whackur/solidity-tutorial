# Q-12. tx.origin — drain your vault through a phisher lure

> **Difficulty**: Beginner ⭐⭐

A pre-funded `Q12TxOriginLab` is deployed. Each user gets a personal `(Q12TxOriginVault, Q12Phisher)` pair. The vault authenticates with `tx.origin == owner` instead of `msg.sender == owner`, so an intermediate contract can abuse a transaction that the owner willingly starts.

## Goal

Make `Q12TxOriginLab.isSolved(yourAddress)` return `true` by demonstrating the phishing-shaped authorization failure in your own instance.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address phisher);
function vaultOf(address user) external view returns (Q12TxOriginVault);
function phisherOf(address user) external view returns (Q12Phisher);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 5 ether;

// Q12TxOriginVault (your personal instance — DO NOT FIX)
function transferTo(address payable to, uint256 amount) external;
function owner() external view returns (address);

// Q12Phisher (your personal instance, beneficiary = you)
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

The dangerous part is not a complex cryptographic bypass. It is the call stack: the owner signs the top-level transaction, but the immediate caller seen by the vault may be a different contract.

## What you can interact with

- A personal vault and a personal phishing contract.
- The phishing contract represents an intermediate caller that the vault mistakes for trusted ownership.

## Hints

- The vulnerable check trusts the transaction origin, not the immediate caller.
- The lure succeeds because the user initiates the transaction themselves.
- Follow the call stack mentally; that is the whole trick.

## Constraints

- Work with your own instance pair.
- This is a phishing-shaped authorization bug, not a password reset.

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
