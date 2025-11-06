// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract EthSign {
    function recoverEthSign(bytes32 _hash, bytes memory _signature) public pure returns (address) {
        bytes32 prefixedHash = MessageHashUtils.toEthSignedMessageHash(_hash);
        return ECDSA.recover(prefixedHash, _signature);
    }

    function recoverPersonalSign(bytes memory _message, bytes memory _signature) public pure returns (address) {
        bytes32 prefixedHash = MessageHashUtils.toEthSignedMessageHash(_message);
        return ECDSA.recover(prefixedHash, _signature);
    }
}