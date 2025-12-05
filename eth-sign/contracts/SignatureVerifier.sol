// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SignatureVerifier
 * @notice Contract for testing eth_sign and personal_sign signature verification
 * @dev Uses OpenZeppelin's ECDSA library for signature verification
 *
 * IMPORTANT NOTES:
 * - eth_sign: Signs a 32-byte hash with EIP-191 prefix
 * - personal_sign: Signs arbitrary data with EIP-191 prefix
 * - Both methods add the "\x19Ethereum Signed Message:\n" prefix
 * - When using wallet libraries (MetaMask, viem), the prefix is added client-side
 * - This contract expects signatures that already have the prefix applied
 */
contract SignatureVerifier {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Event emitted when a signature is verified
    event SignatureVerified(address indexed signer, bytes32 messageHash, string signatureType);

    /**
     * @notice Verifies an eth_sign signature
     * @dev Expects a signature created by signing a raw 32-byte hash
     *      The wallet adds: keccak256("\x19Ethereum Signed Message:\n32" + messageHash)
     * @param messageHash The original message hash (32 bytes) BEFORE prefixing
     * @param signature The signature bytes (already includes the EIP-191 prefix in signing)
     * @return signer The address that signed the message
     */
    function verifyEthSign(bytes32 messageHash, bytes memory signature) public returns (address signer) {
        // The signature was created over the prefixed hash
        // We need to recreate the same prefixed hash to recover the signer
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        signer = ethSignedMessageHash.recover(signature);

        emit SignatureVerified(signer, messageHash, "eth_sign");
        return signer;
    }

    /**
     * @notice Verifies a personal_sign signature
     * @dev Expects a signature created by signing raw message data
     *      The wallet adds: keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
     * @param message The original message (arbitrary length) BEFORE prefixing
     * @param signature The signature bytes (already includes the EIP-191 prefix in signing)
     * @return signer The address that signed the message
     */
    function verifyPersonalSign(bytes memory message, bytes memory signature) public returns (address signer) {
        // Use the bytes overload: this correctly prefixes the raw message
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        signer = ethSignedMessageHash.recover(signature);

        emit SignatureVerified(signer, keccak256(message), "personal_sign");
        return signer;
    }

    /**
     * @notice Verifies that a signature was created by the expected signer (eth_sign)
     * @param messageHash The original message hash
     * @param signature The signature bytes
     * @param expectedSigner The expected signer address
     * @return isValid True if the signature is valid
     */
    function verifyEthSignSigner(bytes32 messageHash, bytes memory signature, address expectedSigner)
        public
        returns (bool isValid)
    {
        address signer = verifyEthSign(messageHash, signature);
        return signer == expectedSigner;
    }

    /**
     * @notice Verifies that a signature was created by the expected signer (personal_sign)
     * @param message The original message
     * @param signature The signature bytes
     * @param expectedSigner The expected signer address
     * @return isValid True if the signature is valid
     */
    function verifyPersonalSignSigner(bytes memory message, bytes memory signature, address expectedSigner)
        public
        returns (bool isValid)
    {
        address signer = verifyPersonalSign(message, signature);
        return signer == expectedSigner;
    }

    /**
     * @notice Pure function to recover signer from eth_sign signature
     * @param messageHash The original message hash
     * @param signature The signature bytes
     * @return signer The address that signed the message
     */
    function recoverEthSignSigner(bytes32 messageHash, bytes memory signature) public pure returns (address signer) {
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        return ethSignedMessageHash.recover(signature);
    }

    /**
     * @notice Pure function to recover signer from personal_sign signature
     * @param message The original message
     * @param signature The signature bytes
     * @return signer The address that signed the message
     */
    function recoverPersonalSignSigner(bytes memory message, bytes memory signature)
        public
        pure
        returns (address signer)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        return ethSignedMessageHash.recover(signature);
    }
}
