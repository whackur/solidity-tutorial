// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SolutionRef {
    using MessageHashUtils for bytes32;

    function recoverEthSign(bytes32 messageHash, bytes memory signature)
        external
        pure
        returns (address)
    {
        bytes32 prefixed = messageHash.toEthSignedMessageHash();
        return ECDSA.recover(prefixed, signature);
    }

    function recoverPersonalSign(bytes memory message, bytes memory signature)
        external
        pure
        returns (address)
    {
        bytes32 prefixed = MessageHashUtils.toEthSignedMessageHash(message);
        return ECDSA.recover(prefixed, signature);
    }
}
