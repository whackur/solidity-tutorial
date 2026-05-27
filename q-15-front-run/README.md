# Q-15. Front-running — read the "private" secret from storage

> **Difficulty**: Beginner ⭐⭐

A pre-funded `Q15FrontRunLab` is deployed. Each user calls `createInstance()` to get a personal `Q15FrontRunChallenge` holding `1 ETH` and a `bytes32 private _secret` that the designer mistakenly thought was hidden.

Your task is to prove that "private" storage is not actually secret and use that knowledge to win your own challenge instance.

## Goal

Make `Q15FrontRunLab.isSolved(yourAddress)` return `true`: be the
`winner` of your own `Q15FrontRunChallenge`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address challenge);
function challengeOf(address user) external view returns (Q15FrontRunChallenge);
function isSolved(address user) external view returns (bool);
uint256 public constant PRIZE = 1 ether;

// Q15FrontRunChallenge (per user, prize seeded by lab)
function claim(bytes32 guess) external;
function owner() external view returns (address);
function winner() external view returns (address);
```

## The bug under attack

Solidity `private` only restricts *contract-level* access. Storage is public on every node, and storage layout is deterministic enough that off-chain tooling can inspect it.

This is also the canonical front-running shape: the *intended* legitimate
solver would put sensitive data in calldata. While that tx sits in the mempool, anyone watching can reuse the revealed data with better ordering and steal the prize before the original lands.

## What you can interact with

- A personal challenge contract with a hidden-looking secret and a claim function.

## Hints

- `private` only limits Solidity source access, not chain data access.
- Think about what data is still publicly readable once a contract is deployed.
- The first reader to learn the secret can usually claim the prize before anyone else.

## Constraints

- Do not rely on the exact storage layout being explained here.
- The lesson is visibility, not a memorized slot index.

## Concepts exercised

- **Solidity `private` ≠ hidden**: storage is encoded into 32-byte slots
  whose layout is deterministic, observable, and indexable by any node.
- **Mempool visibility** = front-running surface. The lab's secret-in-
  storage shape collapses this to a single read-then-write, but the
  pedagogical point is the same: if it's *anywhere* a third party can
  see, they can act first.
- **Commit-reveal** is the standard fix. Two-phase scheme: phase 1
  `commit(keccak256(secret, salt))` puts only a hash on-chain; phase 2
  `reveal(secret, salt)` finalises after a delay.

## Defending it

Commit-reveal sketch:

```solidity
mapping(address => bytes32) public commits;
mapping(address => uint256) public commitBlock;

function commit(bytes32 hash) external {
    commits[msg.sender] = hash;
    commitBlock[msg.sender] = block.number;
}

function reveal(bytes32 secret, bytes32 salt) external {
    require(block.number > commitBlock[msg.sender] + 5, "wait");
    require(commits[msg.sender] == keccak256(abi.encode(secret, salt)), "bad commit");
    // ... proceed with secret-aware logic
}
```

For higher-value applications: MEV-aware ordering (Flashbots, MEV-Share,
threshold encryption / Shutter), or move the privileged action off the
public mempool entirely (private relays, L2 sequencer batching).
