// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SignatureVerifier
 * @notice Example contract comparing eth_sign and personal_sign signature verification
 * @dev Uses OpenZeppelin's ECDSA library for signature verification
 *
 * Key Differences:
 * - eth_sign: Takes a 32-byte hash as input for signing
 *   Prefix added by wallet: "\x19Ethereum Signed Message:\n32" + messageHash
 *
 * - personal_sign: Takes arbitrary length message as input for signing
 *   Prefix added by wallet: "\x19Ethereum Signed Message:\n<length>" + message
 *
 * Both methods follow the EIP-191 standard but differ in input data format
 */
contract SignatureVerifier {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /**
     * @notice Recover signer address from eth_sign signature (pure function)
     * @dev Verifies signature for a 32-byte hash
     *      Wallet signs: keccak256("\x19Ethereum Signed Message:\n32" + messageHash)
     * @param messageHash Original message hash (32 bytes, before prefixing)
     * @param signature Signature bytes
     * @return signer Signer address
     */
    function recoverEthSignSigner(bytes32 messageHash, bytes memory signature)
        public
        pure
        returns (address signer)
    {
        // Recreate the same prefix applied during signing
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        return ethSignedMessageHash.recover(signature);
    }

    /**
     * @notice Recover signer address from personal_sign signature (pure function)
     * @dev Verifies signature for arbitrary length message
     *      Wallet signs: keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
     * @param message Original message (arbitrary length, before prefixing)
     * @param signature Signature bytes
     * @return signer Signer address
     */
    function recoverPersonalSignSigner(bytes memory message, bytes memory signature)
        public
        pure
        returns (address signer)
    {
        // Recreate the same prefix applied during signing
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        return ethSignedMessageHash.recover(signature);
    }

    /**
     * @notice Verify that eth_sign signature was created by expected signer
     * @param messageHash Original message hash
     * @param signature Signature bytes
     * @param expectedSigner Expected signer address
     * @return isValid True if signature is valid
     */
    function verifyEthSign(bytes32 messageHash, bytes memory signature, address expectedSigner)
        public
        pure
        returns (bool isValid)
    {
        address signer = recoverEthSignSigner(messageHash, signature);
        return signer == expectedSigner;
    }

    /**
     * @notice Verify that personal_sign signature was created by expected signer
     * @param message Original message
     * @param signature Signature bytes
     * @param expectedSigner Expected signer address
     * @return isValid True if signature is valid
     */
    function verifyPersonalSign(
        bytes memory message,
        bytes memory signature,
        address expectedSigner
    ) public pure returns (bool isValid) {
        address signer = recoverPersonalSignSigner(message, signature);
        return signer == expectedSigner;
    }
}
