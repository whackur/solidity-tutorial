# vulnerabilities

> Integrated lab directory for lecture *4-1 (attack exercises and secure coding for smart contract vulnerabilities)*.
>
> Each of the four classic vulnerabilities is presented as a *Vulnerable* / *Safe* pair, so each directory shows both *the attack working in practice* and *the defended version blocking it*.

## Directory structure

| Folder | Topic | Key files |
|---|---|---|
| `src/reentrancy/` | The DAO-style reentrancy (CEI violation) | `VulnerableVault.sol`, `SafeVault.sol`, `ReentrancyAttacker.sol` |
| `src/tx-origin/` | `tx.origin` auth bypass (via phishing contract) | `VulnerableWallet.sol`, `SafeWallet.sol`, `Phisher.sol` |
| `src/signature-replay/` | Missing nonce/deadline/domain → reusing the same signature | `VulnerableSigClaim.sol`, `SafeSigClaim.sol` |
| `src/oracle-manipulation/` | Single-pool spot price oracle | `MockPool.sol`, `VulnerableLending.sol`, `SafeLending.sol` |

## Learning goals

- Identify exactly *which line of code* each vulnerability starts from.
- See how the patch contract blocks it by *adding or moving a single line* (for example, changing a CEI line placement).
- Compare the *attack succeeds* and *attack fails* scenarios in the same file with Foundry tests.

## Key points

- **Reentrancy** ≈ "Pressing the withdraw button again *before* the ATM balance updates" → CEI (Checks-Effects-Interactions) + `nonReentrant`.
- **tx.origin** ≈ "Admitting someone just by looking at a front-door business card — without checking who the *person directly in front* really is" → always use `msg.sender`.
- **Signature replay** ≈ "A stamp with no expiration or serial number — once received, it works forever" → EIP-712 + nonce + deadline + chainId + verifyingContract.
- **Oracle manipulation** ≈ "Setting the loan amount based only on *one shop's instantaneous quote*" → TWAP / external oracle / multiple sources.

## Run

```bash
forge build
forge test -vv --match-contract ReentrancyTest
forge test -vv --match-contract TxOriginTest
forge test -vv --match-contract SignatureReplayTest
forge test -vv --match-contract OracleManipulationTest
```
