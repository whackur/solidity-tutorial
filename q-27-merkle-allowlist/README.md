# Q-27. Merkle Allowlist — prove your leaf is in the tree

> **Difficulty**: Entry ⭐
> **Companion to**: [`merkle-allowlist/`](../merkle-allowlist/README.md), which shows the same primitive in a working allowlist gate and a pull-based distributor.

An allowlist of ten thousand investors is far too expensive to store on-chain — one storage write per address to add, and as many again to replace. So the operator publishes the list off-chain and commits a single 32-byte fingerprint of it: the merkle root. Anyone can then prove they are in the list without the list ever being written to the chain.

This lab makes you build that proof by hand.

A single `Q27MerkleAllowlistLab` is deployed. It assigns **you** a leaf position derived from your address, and it tells you the exact leaf you must place there. You construct an 8-leaf tree around that leaf, commit its root, and then submit the path that proves your leaf reaches that root.

## Goal

Make `Q27MerkleAllowlistLab.isSolved(yourAddress)` return `true`. That requires a `commitRoot` call followed by a `claim` call whose proof reconstructs the root you committed.

## Contract surface

```solidity
function LEAF_COUNT() external view returns (uint256);        // 8
function PROOF_LENGTH() external view returns (uint256);      // 3
function REQUIRED_AMOUNT() external view returns (uint256);   // 1000 ether

function requiredIndex(address user) external pure returns (uint256);  // your leaf position
function leafFor(address user) external pure returns (bytes32);        // the exact leaf you must use

function commitRoot(bytes32 root) external;                   // replaceable until you claim
function claim(uint256 index, uint256 amount, bytes32[] calldata proof) external;

function computeRoot(bytes32 leaf, uint256 index, bytes32[] calldata proof)
    external pure returns (bytes32);                          // free to call; check your arithmetic

function committedRoot(address user) external view returns (bytes32);
function isSolved(address user) external view returns (bool);
```

## What you can interact with

- `requiredIndex` and `leafFor` are `pure` views. Reading them costs nothing.
- `computeRoot` is public and `pure`. You can feed it candidate paths off-chain and compare the result against the root you intend to commit, before spending any gas.
- `commitRoot` may be called as many times as you like until your claim succeeds.
- Failed claims revert with a typed error — `BadProofLength`, `WrongIndex`, `WrongAmount`, `NoCommittedRoot`, or `RootMismatch(computed, committed)`. The mismatch error hands you the root your path actually produced, which is a debugging aid rather than a leak.

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- A balanced tree of 8 leaves has depth 3, which is why exactly 3 proof elements are required — one sibling per level.
- **The other seven leaves are never inspected.** Fill them with whatever you like. This lab checks that you can compute a path, not that you belong to any real allowlist. That is deliberate, not an oversight.
- Verification here is **index/direction based**, not sorted-pair based. Bit `i` of your index decides the order at level `i`: when the bit is `0` your running node is the left child, when it is `1` it is the right child. Hash the two in the wrong order and you get a different root.
- Everyone gets a different index, so `0` is not a safe guess and a neighbour's path shape will not fit yours.
- Getting the sibling order right is the whole exercise. If your computed root is stable but wrong, suspect direction before you suspect your hashing.

## Why index order matters here

Many production merkle implementations — including OpenZeppelin's `MerkleProof.verify` — hash each pair in sorted byte order. That is a real optimisation: a sorted proof carries no direction bits, so it is smaller. The cost is that a sorted tree cannot express *where* a leaf sits.

When position is data rather than an implementation detail — a claim index that must map to exactly one allocation, for instance — the tree has to be direction-aware, and the caller has to get the order right. This lab uses the direction-aware form so that a sloppy path fails instead of quietly passing.

## Note on scope

This challenge teaches the merkle primitive. It is worth knowing that the security-token standards do not actually use it: ERC-3643 and its T-REX reference implementation, ONCHAINID, ERC-1400-era implementations, and CMTAT all keep per-investor state on-chain and verify claims with ECDSA instead. Merkle proofs earn their place in large one-shot distributions, reserve attestations, and zero-knowledge identity systems. See [`merkle-allowlist/`](../merkle-allowlist/README.md) for why that tradeoff falls the way it does.
