// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Solution {
    /// @notice Recover signer for an `eth_sign` style signature over a 32-byte hash.
    function recoverEthSign(bytes32 messageHash, bytes memory signature)
        external
        pure
        returns (address signer)
    {
        // TODO: prepend the EIP-191 prefix for a 32-byte hash, then ECDSA.recover.
        //       Hint: MessageHashUtils.toEthSignedMessageHash(bytes32)
        messageHash; signature;
        revert("Solution.recoverEthSign: not implemented");
    }

    /// @notice Recover signer for a `personal_sign` style signature over arbitrary bytes.
    function recoverPersonalSign(bytes memory message, bytes memory signature)
        external
        pure
        returns (address signer)
    {
        // TODO: prepend the EIP-191 prefix that includes the message length, then ECDSA.recover.
        //       Hint: MessageHashUtils.toEthSignedMessageHash(bytes memory)
        message; signature;
        revert("Solution.recoverPersonalSign: not implemented");
    }
}
