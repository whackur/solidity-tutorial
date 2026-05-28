# Solidity Challenges (`q-*`) — multi-tenant web-UI CTF set

> Hands-on, transaction-only Solidity challenges.
>
> Each challenge contract is deployed *once* and shared by many users.
> Progress is keyed by `msg.sender`, so any number of learners can solve
> it concurrently. Students do **not** write Solidity — they send
> transactions / read state through a web UI or wallet.
>
> Auto-grading still runs via Forge from inside each `q-*/` for CI / CR
> purposes, but the *student-facing* workflow is purely transactional.

## Layout

```
q-XX-{slug}/
├── README.md            ← English brief: scenario + hints (no ordered solve sequence)
├── foundry.toml
├── package.json
├── src/
│   └── Setup.sol        ← challenge environment + isSolved(address)
├── test/
│   └── Challenge.t.sol  ← multi-user vm.prank grading
```

## Web UI contract

Every challenge's main contract exposes:

```solidity
function isSolved(address user) external view returns (bool);
```

A web UI polls this after each transaction. The contract is otherwise
free-form — see each `README.md` for the per-challenge call surface.

For challenges that need per-user instances (q-04, q-09, q-10, q-12,
q-14, q-15, q-16, q-17, q-18, q-19, q-22, q-25) the main contract is a `Lab` with
`createInstance(...)` that deploys the user's personal challenge
environment.

## Running the auto-grader (instructor / CI)

```bash
# 1. Install dependencies once at the repo root
forge soldeer install
pnpm install

# 2. Run a challenge's test suite
cd q-01-counter
forge test -vv
```

Each `test/Challenge.t.sol` uses `vm.prank` with two distinct addresses to
verify per-user state isolation.

## Difficulty

| # | Challenge | Level | Core idea |
|---|---|---|---|
| q-01 | counter | Entry ⭐ | per-user mapping + custom error selector |
| q-02 | events-errors | Entry ⭐ | three revert encodings — submit each selector |
| q-03 | eth-mailbox | Beginner ⭐⭐ | trigger receive / fallback / named payable |
| q-04 | delegatecall | Beginner ⭐⭐ | per-user (caller, logic) — call vs delegatecall |
| q-05 | simple-wallet | Beginner ⭐⭐ | per-user ETH + ERC-20 deposit/withdraw cycle |
| q-06 | erc20-permit | Intermediate ⭐⭐⭐ | EIP-2612 permit + transferFrom in one tx |
| q-07 | eth-sign | Intermediate ⭐⭐⭐ | EIP-191 eth_sign + personal_sign recovery |
| q-08 | eip712-voucher | Intermediate ⭐⭐⭐ | EIP-712 typed-data voucher validation |
| q-09 | reentrancy | Intermediate ⭐⭐⭐ | per-user vault + attacker — CEI violation |
| q-10 | signature-replay | Intermediate ⭐⭐⭐ | weak signature authorization context |
| q-11 | access-control | Beginner ⭐⭐ | authorization boundary failure |
| q-12 | tx-origin | Beginner ⭐⭐ | tx.origin-based authorization pitfall |
| q-13 | unchecked-call | Beginner ⭐⭐ | silent failure: low-level call return ignored |
| q-14 | dos-revert | Beginner ⭐⭐ | push-payment DoS via reverting receiver |
| q-15 | front-run | Beginner ⭐⭐ | `private` storage secret is publicly readable |
| q-16 | oracle-spot | Intermediate ⭐⭐⭐ | single-pool spot price used as a lending input |
| q-17 | reentrancy-inflate | Intermediate ⭐⭐⭐ | cross-function CEI — shared accounting invariant break |
| q-18 | read-only-reentrancy | Intermediate ⭐⭐⭐ | view returns stale state during withdraw window |
| q-19 | reentrancy-basic | Entry ⭐ | beginner reentrancy with a simplified personal vault |
| q-20 | erc20-basic | Entry ⭐ | ERC-20 allowance flow |
| q-21 | ecrecover-basic | Entry ⭐ | raw `ecrecover(hash, v, r, s)` — identify the trusted signer among candidates |
| q-22 | spot-price-basic | Entry ⭐ | xy=k mock pool — spot price sensitivity |
| q-23 | storage-slots | Entry ⭐ | read `private` storage and an explicit keccak slot with `eth_getStorageAt` |
| q-24 | nft-ownership | Entry ⭐ | ERC-721 ownership and approval flow |
| q-25 | uups-upgrade | Beginner ⭐⭐ | per-user UUPS proxy and owner-gated upgrade surface |
| q-26 | meta-tx | Intermediate ⭐⭐⭐ | ERC-2771 forwarder and recovered sender context |

## Recommended path

- **Track A (entry — Solidity basics)**: q-01 → q-02 → q-03 → q-04 → q-05
- **Track B (intermediate — core)**: q-06 → q-07 → q-08 → q-09 → q-10
- **Track C (vulnerability categories, beginner)**: q-11 → q-12 → q-13 → q-14 → q-15
- **Track D (vulnerability categories, intermediate)**: q-16 → q-17 → q-18
- **Track E (DeFi hacks playthrough)**: q-19 (warm-up) → q-09 (The DAO) → q-14 (King of the Ether) → q-16 (Cream Finance) → q-11 (Poly Network)
- **Track F (advanced platform features)**: q-23 → q-24 → q-25 → q-26

## Paired progression (warm-up → applied)

Each row introduces a single concept with a compact warm-up, then immediately re-uses it in a real-shaped applied challenge. Use this path when teaching the same topic across two consecutive slots.

| # | Concept | Warm-up (Entry ⭐) | Applied (Beginner / Intermediate) |
|---|---|---|---|
| 1 | ERC-20 transfer flow | **q-20 erc20-basic** | q-05 simple-wallet · q-06 erc20-permit |
| 2 | Signature recovery | **q-21 ecrecover-basic** | q-07 eth-sign · q-08 eip712-voucher · q-10 signature-replay |
| 3 | Reentrancy / CEI | **q-19 reentrancy-basic** | q-09 reentrancy · q-17 reentrancy-inflate · q-18 read-only-reentrancy |
| 4 | AMM / oracle | **q-22 spot-price-basic** | q-16 oracle-spot |
| 5 | Storage visibility | **q-23 storage-slots** | q-15 front-run · q-25 uups-upgrade |
| 6 | ERC-721 approval flow | **q-24 nft-ownership** | NFT marketplace / custody patterns |
| 7 | EVM call semantics | q-01 counter | q-04 delegatecall · q-13 unchecked-call |
| 8 | Access control | q-02 events-errors | q-11 access-control · q-12 tx-origin |
| 9 | ETH delivery edge cases | q-03 eth-mailbox | q-14 dos-revert · q-15 front-run |
| 10 | Meta-transactions | q-21 ecrecover-basic | q-26 meta-tx |

## Rules

- `src/Setup.sol` is the deployed bytecode — do not modify in PRs that
  change the challenge semantics; instead create a v2.
- Every challenge's main contract must keep `isSolved(address user)`
  stable; the UI grader depends on it.
- Tests must cover at least two users solving in parallel under `vm.prank`.
- No `src/Solution.sol`, no `reference/PLAYBOOK.md`, and no `reference/Solution.ref.sol`.
- Public README files may include goals, contract surfaces, and hints, but must not include full ordered solve sequences.

See [`AGENTS.md`](AGENTS.md) for the full design rules.
