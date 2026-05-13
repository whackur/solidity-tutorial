# Q-15. Front-running — read the "private" secret from storage

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-15-front-run.md`](../../solidity-tutorial-lecture/docs/challenges/q-15-front-run.md)
> **Lecture (Korean)**: [PPT 4-1 §8](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A pre-funded `FrontRunLab` is deployed. Each user calls `createInstance()`
to get a personal `FrontRunChallenge` holding `1 ETH` and a `bytes32
private _secret` that the designer mistakenly thought was hidden.
You read the secret directly off-chain via `eth_getStorageAt(addr, 1)`
and submit it back through `claim(secret)` to take the prize.

## Goal

Make `FrontRunLab.isSolved(yourAddress)` return `true`: be the
`winner` of your own `FrontRunChallenge`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address challenge);
function challengeOf(address user) external view returns (FrontRunChallenge);
function isSolved(address user) external view returns (bool);
uint256 public constant PRIZE = 1 ether;

// FrontRunChallenge (per user, prize seeded by lab)
function claim(bytes32 guess) external;
function owner() external view returns (address);
function winner() external view returns (address);
function secretSlot() external pure returns (uint256);   // returns 1
```

## The bug under attack

```solidity
contract FrontRunChallenge {
    address public owner;
    bytes32 private _secret;        // ← "private" is NOT hidden
    address public winner;
    ...
}
```

Solidity `private` only restricts *contract-level* access. Storage is
public on every node. Any client can call:

```ts
const secret = await publicClient.getStorageAt({
  address: challenge,
  slot: 1n,
});
```

…and then submit `claim(secret)` first.

This is also the canonical front-running shape: the *intended* legitimate
solver would put the secret in the calldata of their `claim` tx. While
that tx sits in the mempool, anyone watching can submit their own
`claim(secret)` with higher priority fee and steal the prize before the
original lands.

## UI call sequence

1. `lab.createInstance()` — deploys your challenge, seeds `1 ETH`.
2. Off-chain (viem):

   ```ts
   const challenge = await lab.read.challengeOf([you]);
   const secret = await publicClient.getStorageAt({ address: challenge, slot: 1n });
   ```

3. `challenge.claim(secret)` — `winner = you`, prize lands in your wallet.
4. `lab.isSolved(you)` → `true`.

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
