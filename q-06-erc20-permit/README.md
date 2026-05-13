# Q-06. ERC20Permit — approve + transferFrom in one transaction

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-06-erc20-permit.md`](../../solidity-tutorial-lecture/docs/challenges/q-06-erc20-permit.md)
> **Lecture (Korean)**: [PPT 3-2](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-2-erc20.md), [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md)
> **Reference source**: [`../erc20-extended/src/ExtendedERC20.sol`](../erc20-extended/src/ExtendedERC20.sol)

## Scenario

EIP-2612 `permit` turns an off-chain signature into an on-chain allowance. The test prepares an `(owner, ownerPk)` pair with token balance, builds the typed digest, and signs it with `vm.sign`. Your job:

1. `token.permit(owner, address(this), value, deadline, v, r, s)` — verifies the signature and writes the allowance.
2. `IERC20(address(token)).transferFrom(owner, recipient, value)` — pulls the tokens.

## What to implement

```solidity
function pullWithPermit(
    IERC20Permit token,
    address owner,
    uint256 value,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s,
    address recipient
) external;
```

## Hints

- Order matters — call `permit` **before** `transferFrom`.
- A signature is valid only once; the second consume reverts (`ERC2612InvalidSigner` or similar) because the nonce was bumped.

## Grading

```bash
forge test -vv
```

- `test_PullWithPermit` — recipient holds the tokens, owner is empty.
- `test_NonceConsumed` — re-using the same signature reverts.
