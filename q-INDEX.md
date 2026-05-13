# Solidity Challenges (`q-*`) — CTF-style learning set

> Hands-on challenges that pair with the **`solidity-tutorial-lecture`** theory (Korean).
> Each challenge stands alone and is graded by a single `forge test` run.
>
> **Korean problem briefs** live in [`solidity-tutorial-lecture/docs/challenges/`](../solidity-tutorial-lecture/docs/challenges/README.md). Source code, tests, and English READMEs live here.

## How to run a challenge

```bash
# 1. Install dependencies (once)
forge soldeer install
pnpm install

# 2. Pick a challenge and run the auto-grader
cd q-01-counter
forge build
forge test -vv          # starts failing; fill in src/Solution.sol; re-run
```

Each challenge has the same layout:

```
q-XX-{slug}/
├── README.md            ← English brief (this repo's language)
├── foundry.toml
├── package.json
├── src/
│   ├── Setup.sol        ← the challenge environment — DO NOT EDIT
│   └── Solution.sol     ← TODOs to fill in
└── test/
    └── Challenge.t.sol  ← auto-grading
```

> Korean brief: [`../solidity-tutorial-lecture/docs/challenges/q-XX-{slug}.md`](../solidity-tutorial-lecture/docs/challenges/README.md) — open the lecture repo for the problem statement in Korean.

A `reference/` folder ships a working instructor solution. Students should not peek; smoke-test scripts can swap it in temporarily.

## Difficulty & lecture mapping

| # | Challenge | Level | PPT mapping | Core idea |
|---|---|---|---|---|
| q-01 | counter | Entry ⭐ | 2-2 | state + event + custom error |
| q-02 | events-errors | Entry ⭐ | 1-3, 2-2 | selector arithmetic + try/catch branches |
| q-03 | eth-mailbox | Beginner ⭐⭐ | 1-3, 2-3 | receive / fallback / payable routing |
| q-04 | delegatecall | Beginner ⭐⭐ | 1-1, 2-3 | call vs delegatecall storage |
| q-05 | simple-wallet | Beginner ⭐⭐ | 2-4 | ERC-20 approve + deposit/withdraw |
| q-06 | erc20-permit | Intermediate ⭐⭐⭐ | 3-2 | EIP-2612 permit + transferFrom |
| q-07 | eth-sign | Intermediate ⭐⭐⭐ | 3-4 | `eth_sign` vs `personal_sign` ECDSA recovery |
| q-08 | eip712-voucher | Intermediate ⭐⭐⭐ | 3-4 | EIP-712 typed-data digest by hand |
| q-09 | reentrancy | Intermediate ⭐⭐⭐ | 4-1 | CEI violation + re-entrant attacker |
| q-10 | signature-replay | Intermediate ⭐⭐⭐ | 3-4, 4-1 | nonce-less signature reuse |

## Recommended path

- **Track A (entry)**: q-01 → q-02 → q-03 → q-04 → q-05
- **Track B (intermediate)**: q-06 → q-07 → q-08 → q-09 → q-10

## Rules

- Do not edit `src/Setup.sol` — it backs the grading.
- Only fill in the `TODO`s inside `src/Solution.sol`.
- Multiple solutions can pass — passing tests are the only requirement.
- Gas optimization is a bonus, not a requirement.
