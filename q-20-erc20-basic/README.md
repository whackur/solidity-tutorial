# Q-20. ERC-20 Basic — approve, then let a vault pull your tokens

> **Difficulty**: Entry ⭐
> **Companion to**: [`q-05-simple-wallet/`](../q-05-simple-wallet/README.md) and [`q-06-erc20-permit/`](../q-06-erc20-permit/README.md). This is the first contact with the **approve + transferFrom** flow that those two challenges then apply.

A single `Q20Erc20BasicLab` is deployed. Inside the lab there is one shared `Q20Faucet` (a tiny hand-rolled ERC-20 with a per-user `claim()`) and one shared `Q20PullVault` that pulls tokens from depositors via `transferFrom`. Every learner solves in parallel because all per-user state lives in `claimed[]` and `deposited[]`.

There is no exploit here — the goal is to **see how an ERC-20 transfer actually works** when a contract is the spender. Three transactions, no Solidity to write.

## Goal

Make `Q20Erc20BasicLab.isSolved(yourAddress)` return `true`. That requires:

1. `faucet.claimed[you] == true` — you claimed your one-time mint.
2. `vault.deposited[you] >= TARGET` (25 MNT).

## Contract surface

```solidity
// Lab
function isSolved(address user) external view returns (bool);
function faucet() external view returns (Q20Faucet);
function vault() external view returns (Q20PullVault);
uint256 public constant TARGET = 25e18;

// Q20Faucet (shared; per-user claim guard)
function claim() external;
function claimed(address user) external view returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function transfer(address to, uint256 amount) external returns (bool);
function balanceOf(address user) external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256);
uint256 public constant CLAIM_AMOUNT = 100e18;

// Q20PullVault (shared; per-user deposited tally)
function pull(uint256 amount) external;             // calls transferFrom(msg.sender, vault, amount)
function deposited(address user) external view returns (uint256);
```

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

## What you can interact with

- A faucet that mints `CLAIM_AMOUNT` once per address.
- A vault whose `pull` is permissionless but requires you to have approved it first.
- Standard ERC-20 functions on the faucet contract (`balanceOf`, `allowance`, `approve`, `transfer`).

## Hints

- The vault never *takes* tokens — it *pulls* them. The pull only succeeds if you already gave it permission.
- Try calling `vault.pull(25e18)` *before* approving — read the revert reason. Then approve and try again.
- After `approve`, call `faucet.allowance(yourAddress, vaultAddress)` and note the number. After `pull()` succeeds, call `allowance` again — watch the remaining budget decrease by exactly the pulled amount.
- A *direct* `transfer(vault, 25e18)` does not change `deposited[you]`. The vault only updates its bookkeeping when it pulls via `transferFrom`.
- Want a guided Solidity walkthrough of the same flow before attempting this challenge? See [`erc20-allowance/`](../erc20-allowance/) for a step-by-step tutorial.

## Constraints

- One claim per address. Q20Faucet enforces this with `claimed[]`.
- `pull(amount)` must be called by *you*; the inner `transferFrom` decrements `allowance[you][vault]`, not someone else's.

## Concepts exercised

- **`balanceOf` vs `allowance`**: balance is what you own; allowance is the per-spender budget you authorize.
- **`transfer` vs `transferFrom`**: `transfer` moves *your* tokens (caller is the source); `transferFrom` moves *someone else's* tokens after they approved you (caller is the spender).
- **Why DEX / staking / lending contracts *always* go through `approve` + `transferFrom`**: the contract cannot move your tokens without your explicit allowance — there is no implicit access.
- **The replay-style problem this introduces**: every interaction needs a separate `approve` transaction. That two-tx friction is exactly what [`q-06-erc20-permit/`](../q-06-erc20-permit/README.md) removes by signing an EIP-2612 permit instead.

## Where this leads

- [`q-05-simple-wallet/`](../q-05-simple-wallet/README.md) — a wallet that holds your ERC-20 deposits behind the same `approve + transferFrom` pattern, now combined with ETH deposits.
- [`q-06-erc20-permit/`](../q-06-erc20-permit/README.md) — replace `approve()` with an off-chain signature (`permit()`); same `transferFrom` payoff.
