# Q-07. ECDSA recovery — eth_sign vs personal_sign

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-07-eth-sign.md`](../../solidity-tutorial-lecture/docs/challenges/q-07-eth-sign.md)
> **Lecture (Korean)**: [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md)
> **Reference source**: [`../eth-sign/src/SignatureVerifier.sol`](../eth-sign/src/SignatureVerifier.sol)

## Scenario

Two EIP-191 variants differ only in their prefix:

| Variant | Hashed data |
|---|---|
| `eth_sign` | `keccak256("\x19Ethereum Signed Message:\n32" \|\| hash)` |
| `personal_sign` | `keccak256("\x19Ethereum Signed Message:\n" \|\| len(msg) \|\| msg)` |

Recover the signer in both cases using OpenZeppelin's `ECDSA` and `MessageHashUtils`.

## What to implement

```solidity
function recoverEthSign(bytes32 messageHash, bytes memory signature)
    external pure returns (address signer);

function recoverPersonalSign(bytes memory message, bytes memory signature)
    external pure returns (address signer);
```

## Hints

```solidity
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// eth_sign — 32-byte hash overload
bytes32 prefixed = MessageHashUtils.toEthSignedMessageHash(messageHash);
// personal_sign — bytes overload
bytes32 prefixed = MessageHashUtils.toEthSignedMessageHash(message);

return ECDSA.recover(prefixed, signature);
```

## Grading

```bash
forge test -vv
```

- `test_RecoverEthSign` / `test_RecoverPersonalSign` — recovered address equals the expected signer.
- `test_WrongSignerFails` — a different private key yields a different (non-matching) address.
