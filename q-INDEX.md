# Solidity Challenges (`q-*`) — multi-tenant web-UI CTF set

> Hands-on challenges that pair with the **`solidity-tutorial-lecture`**
> theory (Korean briefs).
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
├── README.md            ← English brief: scenario + UI call sequence
├── foundry.toml
├── remappings.txt       ← mirrors foundry.toml for Cursor / VSCode LSP
├── package.json
├── src/
│   └── Setup.sol        ← challenge environment + isSolved(address)
├── test/
│   └── Challenge.t.sol  ← multi-user vm.prank grading
└── reference/
    └── PLAYBOOK.md      ← instructor-only ordered call list
```

Korean brief lives at
`../solidity-tutorial-lecture/docs/challenges/q-XX-{slug}.md`.

## Web UI contract

Every challenge's main contract exposes:

```solidity
function isSolved(address user) external view returns (bool);
```

A web UI polls this after each transaction. The contract is otherwise
free-form — see each `README.md` for the per-challenge call surface.

For challenges that need per-user instances (q-04, q-09, q-10) the main
contract is a `Lab` with `createInstance(...)` that deploys the user's
personal vulnerable/attacker pair.

## Running the auto-grader (instructor / CI)

```bash
# 1. Install dependencies once at the repo root
forge soldeer install
pnpm install

# 2. Run a challenge's test suite
cd q-01-counter
forge test -vv
```

Each `test/Challenge.t.sol` uses `vm.prank` to drive two distinct
addresses through the solve flow and verifies the per-user state is
isolated.

## Difficulty & lecture mapping

| # | Challenge | Level | PPT mapping | Core idea |
|---|---|---|---|---|
| q-01 | counter | Entry ⭐ | 2-2 | per-user mapping + custom error selector |
| q-02 | events-errors | Entry ⭐ | 1-3, 2-2 | three revert encodings — submit each selector |
| q-03 | eth-mailbox | Beginner ⭐⭐ | 1-3, 2-3 | trigger receive / fallback / named payable |
| q-04 | delegatecall | Beginner ⭐⭐ | 1-1, 2-3 | per-user (caller, logic) — call vs delegatecall |
| q-05 | simple-wallet | Beginner ⭐⭐ | 2-4 | per-user ETH + ERC-20 deposit/withdraw cycle |
| q-06 | erc20-permit | Intermediate ⭐⭐⭐ | 3-2, 3-4 | EIP-2612 permit + transferFrom in one tx |
| q-07 | eth-sign | Intermediate ⭐⭐⭐ | 3-4 | EIP-191 eth_sign + personal_sign recovery |
| q-08 | eip712-voucher | Intermediate ⭐⭐⭐ | 3-4 | EIP-712 typed-data signed mint voucher |
| q-09 | reentrancy | Intermediate ⭐⭐⭐ | 4-1 §2 | per-user vault + attacker — CEI violation drain |
| q-10 | signature-replay | Intermediate ⭐⭐⭐ | 3-4, 4-1 §5-2 | per-user claim — replay a nonce-less signature |
| q-11 | access-control | Beginner ⭐⭐ | 4-1 §7 | missing `onlyOwner` setter — self-promote to admin |
| q-12 | tx-origin | Beginner ⭐⭐ | 4-1 §3, 3-2 | phisher contract drains vault via tx.origin auth |
| q-13 | unchecked-call | Beginner ⭐⭐ | 4-1 §4 | silent failure: low-level call return ignored |
| q-14 | dos-revert | Beginner ⭐⭐ | 4-1 §9 | push-payment DoS via reverting receiver |
| q-15 | front-run | Beginner ⭐⭐ | 4-1 §8 | `private` storage secret is publicly readable |
| q-16 | oracle-spot | Intermediate ⭐⭐⭐ | 4-1 §6, 6-2 | single-pool spot price manipulation drains lender |
| q-17 | reentrancy-inflate | Intermediate ⭐⭐⭐ | 4-1 §2, 2-2 | cross-function CEI — same deposit pays out twice |
| q-18 | read-only-reentrancy | Intermediate ⭐⭐⭐ | 4-1 §2-2 | view returns stale state during withdraw window |

## Recommended path

- **Track A (entry)**: q-01 → q-02 → q-03 → q-04 → q-05
- **Track B (intermediate — core)**: q-06 → q-07 → q-08 → q-09 → q-10
- **Track C (vulnerability categories, beginner)**: q-11 → q-12 → q-13 → q-14 → q-15
- **Track D (vulnerability categories, intermediate)**: q-16 → q-17 → q-18

## Rules

- `src/Setup.sol` is the deployed bytecode — do not modify in PRs that
  change the challenge semantics; instead create a v2.
- Every challenge's main contract must keep `isSolved(address user)`
  stable; the UI grader depends on it.
- Tests must cover at least two users solving in parallel under `vm.prank`.
- No `src/Solution.sol` (gone), no `reference/Solution.ref.sol` (gone).
  Instructor walkthroughs live only in `reference/PLAYBOOK.md`.

See [`AGENTS.md`](AGENTS.md) for the full design rules.
