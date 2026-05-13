# Q-10. Signature replay — reuse the same signature N times

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-10-signature-replay.md`](../../solidity-tutorial-lecture/docs/challenges/q-10-signature-replay.md)
> **Lecture (Korean)**: [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md), [PPT 4-1](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)
> **Reference source**: [`../vulnerabilities/src/signature-replay/VulnerableSigClaim.sol`](../vulnerabilities/src/signature-replay/VulnerableSigClaim.sol)

## Scenario

`VulnerableSigClaim.claim(to, amount, signature)` verifies a signature over `(to, amount)` — no nonce, no deadline, no chainId, no verifyingContract. The same signature is valid forever.

The claim contract holds 5 ETH. The signer issued a single signature for `(attacker, 1 ETH)`. Use it five times.

## What to implement

```solidity
function replay(
    IVulnerableSigClaim claim,
    address payable to,
    uint256 amount,
    bytes calldata signature,
    uint256 times
) external;
```

Plus a `receive()` so the contract can hold the drained ETH.

## Hints

- A `for` loop calling `claim.claim(to, amount, signature)` `times` times is all you need.

## Grading

```bash
forge test -vv
```

- `test_ReplayFiveTimes` — claim balance is 0; Solution holds 5 ETH.
