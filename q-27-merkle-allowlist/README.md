# Q-27. Merkle Allowlist — prove your leaf is in the tree

> **Difficulty**: Entry ⭐
> **Companion to**: [`merkle-allowlist/`](../merkle-allowlist/README.md), which shows the same primitive in a working allowlist gate and a pull-based distributor.

An allowlist of ten thousand investors is far too expensive to store on-chain — one storage write per address to add, and as many again to replace. So the operator publishes the list off-chain and commits a single 32-byte fingerprint of it: the merkle root. Anyone can then prove they are in the list without the list ever being written to the chain.

This lab makes you build that proof by hand.

A single `Q27MerkleAllowlistLab` is deployed. It assigns **you** a leaf position derived from your address, and it fills the other seven positions with fixed classroom addresses of its own. So the list is a real list of eight addresses, and the lab will hand you every entry of it: `treeAddresses(you)` returns the addresses in slot order and `treeLeaves(you)` returns their leaves. You rebuild the tree from that list, commit its root, and then submit the path that proves your leaf reaches that root.

## Goal

Make `Q27MerkleAllowlistLab.isSolved(yourAddress)` return `true`. That requires a `commitRoot` call followed by a `claim` call whose proof reconstructs the root you committed.

Because the list is fixed, the root you must commit is fully determined by your address. Committing some other root and then proving a path into it is not a shortcut: `claim` recomputes your leaf from `msg.sender`, so only the path through the real list can reach the root you committed.

## Contract surface

```solidity
function LEAF_COUNT() external view returns (uint256);        // 8
function PROOF_LENGTH() external view returns (uint256);      // 3
function PEER_COUNT() external view returns (uint256);        // 7 fixed classroom addresses

function requiredIndex(address user) external pure returns (uint256);  // your leaf position
function leafOf(address account) external pure returns (bytes32);      // leaf of any list entry
function leafFor(address user) external pure returns (bytes32);        // the exact leaf you must use
function peerAt(uint256 peerIndex) external pure returns (address);    // one fixed classroom address
function treeAddresses(address user) external pure returns (address[8] memory);
function treeLeaves(address user) external pure returns (bytes32[8] memory);

function commitRoot(bytes32 root) external;                   // replaceable until you claim
function claim(uint256 index, bytes32[] calldata proof) external;

function computeRoot(bytes32 leaf, uint256 index, bytes32[] calldata proof)
    external pure returns (bytes32);                          // free to call; check your arithmetic

function committedRoot(address user) external view returns (bytes32);
function isSolved(address user) external view returns (bool);
```

## What you can interact with

- `requiredIndex` and `leafFor` are `pure` views. Reading them costs nothing.
- `computeRoot` is public and `pure`. You can feed it candidate paths off-chain and compare the result against the root you intend to commit, before spending any gas.
- `commitRoot` may be called as many times as you like until your claim succeeds.
- `peerAt`, `treeAddresses`, and `treeLeaves` are `pure` views as well, so the whole list is free to read.
- Failed claims revert with a typed error: `BadProofLength`, `WrongIndex`, `NoCommittedRoot`, or `RootMismatch(computed, committed)`. The mismatch error hands you the root your path actually produced, which is a debugging aid rather than a leak.

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- A balanced tree of 8 leaves has depth 3, which is why exactly 3 proof elements are required — one sibling per level.
- **The other seven entries are fixed, not arbitrary.** `peerAt(0)` through `peerAt(6)` fill every slot other than yours, in ascending slot order, and `treeLeaves(you)` already applies that placement. Nothing about the list is a guess: the work is hashing it up to a root and getting the directions right.
- Every entry, yours included, hashes the same way: `keccak256(bytes.concat(keccak256(abi.encode(account))))`. The list is an ordinary allowlist, and your leaf is an ordinary member of it.
- Verification here is **index/direction based**, not sorted-pair based. Bit `i` of your index decides the order at level `i`: when the bit is `0` your running node is the left child, when it is `1` it is the right child. Hash the two in the wrong order and you get a different root.
- Your index is derived from your address, so `0` is not a safe guess. Two users can share one of the eight positions, but their leaves differ and a neighbour's proof cannot be copied unchanged.
- Getting the sibling order right is the whole exercise. If your computed root is stable but wrong, suspect direction before you suspect your hashing.

## Why index order matters here

Many production merkle implementations — including OpenZeppelin's `MerkleProof.verify` — hash each pair in sorted byte order. That is a real optimisation: a sorted proof carries no direction bits, so it is smaller. The cost is that a sorted tree cannot express *where* a leaf sits.

When position is data rather than an implementation detail — a claim index that must map to exactly one allocation, for instance — the tree has to be direction-aware, and the caller has to get the order right. This lab uses the direction-aware form so that a sloppy path fails instead of quietly passing.

## Note on scope

This challenge teaches the merkle primitive. It is worth knowing that the security-token standards do not actually use it: ERC-3643 and its T-REX reference implementation, ONCHAINID, ERC-1400-era implementations, and CMTAT all keep per-investor state on-chain and verify claims with ECDSA instead. Merkle proofs earn their place in large one-shot distributions, reserve attestations, and zero-knowledge identity systems. See [`merkle-allowlist/`](../merkle-allowlist/README.md) for why that tradeoff falls the way it does.
