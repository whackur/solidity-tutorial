# Q-09. Reentrancy — drain the VulnerableVault

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-09-reentrancy.md`](../../solidity-tutorial-lecture/docs/challenges/q-09-reentrancy.md)
> **Lecture (Korean)**: [PPT 4-1](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)
> **Reference source**: [`../vulnerabilities/src/reentrancy/VulnerableVault.sol`](../vulnerabilities/src/reentrancy/VulnerableVault.sol), [`../vulnerabilities/src/reentrancy/ReentrancyAttacker.sol`](../vulnerabilities/src/reentrancy/ReentrancyAttacker.sol)

## Scenario

`VulnerableVault.withdraw()` sends ETH *before* zeroing the balance — a CEI violation.

```solidity
(bool ok,) = msg.sender.call{value: bal}("");
balances[msg.sender] = 0;   // too late
```

10 ETH are already deposited by honest users. You have 1 ETH of bait. Drain the vault.

## What to implement

`Solution` itself is the attacker:

```solidity
function setVault(IVulnerableVault v) external;
function attack() external payable;
receive() external payable;
function drain(address payable to) external;
```

## Hints

- In `attack`, deposit `msg.value` into the vault, then call `withdraw` to start the recursion.
- In `receive()`, while `address(vault).balance >= attackAmount` keep calling `withdraw()`. Without the guard the recursion runs out of gas.
- `drain` forwards `address(this).balance` to `to`.

## Grading

```bash
forge test -vv
```

- `test_VaultDrained` — `address(vault).balance == 0`.
- `test_AttackerHolds11Eth` — Solution holds ≥ 11 ETH (bait + victim funds).
