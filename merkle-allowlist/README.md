# merkle-allowlist — commit a root, not a list

Two production patterns built on merkle proofs: gating access from a committed allowlist root, and distributing tokens by pull-claim instead of a push loop.

The package also includes `AllowlistRestrictedToken`, a classroom-sized ERC-20 that asks the gate about both sender and recipient on every transfer. It makes the movement restriction visible, but it is intentionally not a complete security-token or ERC-3643 implementation.

The idea in one line: instead of writing one storage slot per allowed address, publish the list off-chain and store a single 32-byte fingerprint of it on-chain. Anyone can then prove they are in the list; nobody has to pay to put the list there.

## Why a root instead of a list

Storing an allowlist on-chain costs one cold `SSTORE` per address. A list of ten thousand investors is ten thousand writes to add and ten thousand more to replace. A root is one word — the cost of committing is the same whether the tree has eight leaves or eight million.

The cost moves rather than disappearing. Each member now supplies a proof of about `log2(n)` hashes with every registration, and somebody has to build the tree, publish it, and serve proofs. That operational burden is the real price of this pattern, and it is why it fits airdrops (publish once, claim once) far better than a register that changes daily.

## `MerkleAllowlist`

- `commitRoot(bytes32)` — caller commits or replaces the root of the list it belongs to.
- `register(uint256 index, bytes32[] proof)` — caller proves its own leaf at a direction-aware index.
- `isAllowed(address)` — cheap check for everything downstream.
- `revoke()` — caller revokes only its own access; the committed root is left in place.
- `leafFor(address)` — the leaf an address occupies in the list.
- `computeRoot(bytes32 leaf, uint256 index, bytes32[] proof)` — free path calculator with the same directional order as Q-27.
- `LEAF_COUNT()` — fixed at `8`; valid leaf indexes are `0` through `7`.
- `PROOF_LENGTH()` — fixed at `3`; every registration supplies one sibling for each tree level.

This classroom gate has no owner or administrator. Every account commits its own root and tracks its own access, which makes one deployment safe for many learners at the same time. The list itself can still be shared: a group of eight builds one tree over their eight addresses, each member commits that same root, and each member registers with its own index and path. Commit order and registration order do not matter, because nothing in the leaf depends on anybody else's progress.

The exercise uses a fixed eight-leaf tree, so a registration must provide exactly three proof elements and an index below eight. Invalid length or range is rejected before proof verification. Leaves are `keccak256(bytes.concat(keccak256(abi.encode(account))))`: the entry is the address and nothing else, which is what lets a group share one list. The double hash is the OpenZeppelin convention for leaves with attacker-influenced preimages: a leaf and an internal node must never be confusable, or someone can present a 64-byte internal node as a leaf. At each proof level, index bit `i` chooses `abi.encode(node, sibling)` for a left node or `abi.encode(sibling, node)` for a right node. This direction-aware path is the same arithmetic used by Q-27.

Registration is single-shot per account: an already-registered caller is rejected with `AlreadyRegistered`, so granting access always corresponds to exactly one successful call. `revoke()` clears only the caller's own access and leaves its committed root untouched, so the same list and the same path register again afterwards. That makes the cycle register, revoke, register available for as many rounds as a learner wants, without rebuilding the tree.

## `MerkleDistributor`

Leaves commit `(index, account, amount)`. `claim(index, account, amount, proof)` verifies the proof, marks the index claimed, and transfers to `account`.

Two details worth reading the code for:

**Claims are tracked in a bitmap.** A `mapping(uint256 => bool)` burns a full cold storage slot per claim. Packing 256 claim flags into one word amortises that, and consecutive claimers in the same word pay the warm-write price instead.

**`claim` pays `account`, never `msg.sender`.** Anyone may submit somebody else's proof and the tokens still land on the rightful account. That is intended: an operator can batch-submit claims for recipients without ever being able to redirect funds.

### Push versus pull

A push distribution loops over recipients inside one transaction. If the token is allowed to refuse a transfer — and a compliance-gated token is *built* to refuse transfers — then one recipient who is no longer allowed to receive makes the whole call revert. Every other recipient is held hostage by that one address, and the distribution cannot complete at all.

With pull, the blocked recipient fails their own claim and nobody else notices. The unclaimed allocation stays visible on-chain as an unset bit rather than being silently skipped. `test_BlockedRecipientDoesNotStopOthers` demonstrates it against a token that blocks one address.

## `AllowlistRestrictedToken`

The token checks `isAllowed(from)` and `isAllowed(to)` before a normal transfer. A learner can therefore compare three observable cases: an unregistered recipient is rejected, two registered addresses can transfer, and an explicit revocation blocks the next movement.

This is a teaching bridge from an address list to a transfer gate. Real regulated-token systems also need identity claims, expiry, jurisdiction rules, roles, recovery, forced transfer, evidence, and off-chain operating procedures. A Merkle root does not provide those controls by itself.

## Why the security-token standards do not do this

This is worth knowing before reaching for merkle trees in a regulated context: **the security-token standards do not use them anywhere.**

- The ERC-3643 specification text contains no merkle anything. Neither does its T-REX reference implementation, nor the ERC-3643 organisation's repository.
- ONCHAINID stores ERC-734/735 claims fully on-chain and validates them with ECDSA through `IClaimIssuer.isClaimValid()`.
- ERC-1400-era implementations such as polymath-core pay dividends from on-chain checkpoints (`balanceOfAt(payee, checkpointId)`).
- CMTAT, used in real issuances, distributes from a snapshot module.

None of them were short of options — OpenZeppelin's `MerkleProof` has been available the entire time. Not using it was a choice, and the reasons are operational rather than cryptographic:

- An issuer must be able to query, correct, and force-transfer against the register at any moment. A root is opaque; you cannot enumerate or amend it on-chain.
- Every change to the member set means regenerating the tree, re-committing, and keeping a proof-serving service running. A register that changes daily makes that a permanent operational dependency.
- Holder counts are in the hundreds to low thousands, not millions. The gas saved is small next to the cost of running that infrastructure.

Available cryptography is not automatically the right fit for a regulated workflow. Where merkle trees genuinely are deployed in production is a different shape of problem: one-shot airdrops with very large recipient sets, reserve-balance attestations, and zero-knowledge identity systems where the root is an input to a proof rather than a lookup table.

## What this does NOT do

- **No privacy.** A root alone reveals nothing, but holders cannot build proofs without the tree, so the tree gets published — and publishing it publishes the whole membership set. This hides nothing from anyone who reads the tree.
- **No personal data belongs in a leaf.** Hashing a name, a birthdate, or a document does not protect it: the input space is small enough to enumerate, so the hash is reversible by guessing. Commit judgements and expiries, not identities.
- **Each account controls its own root.** Nothing here proves that a learner's committed tree matches an approved list. This is a classroom interaction model, not an issuer control.
- **Replacing a root does not remove anybody.** `commitRoot` only changes what the next registration is checked against; an account that already registered keeps access until it calls `revoke()`. Removal is a per-address operation.
- **This allowlist uses direction-aware paths.** The separate distributor still uses OpenZeppelin sorted-pair proofs and commits its index inside each leaf.

## Run

```bash
cd merkle-allowlist
forge build
forge test -vv
```

Deployment creates an empty ownerless allowlist; every account commits its own root afterwards. `DISTRIBUTION_MERKLE_ROOT` supplies the distributor's fixed pull-claim tree, and `SHARED_ERC20` selects the distributed token, falling back to a local mock. The distributor root is `immutable`: deploying without `DISTRIBUTION_MERKLE_ROOT` leaves a distributor that can never settle a claim.
