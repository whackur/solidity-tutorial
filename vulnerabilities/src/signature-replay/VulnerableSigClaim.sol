// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title VulnerableSigClaim — verifies signatures on a plain hash without *nonce/deadline/domain*
/// @notice The same signature can be submitted multiple times (signature replay) + cross-replay to other chains/contracts is possible
contract VulnerableSigClaim {
    address public immutable signer;

    constructor(address s) {
        signer = s;
    }

    function claim(address payable to, uint256 amount, bytes calldata signature) external {
        // BAD: no nonce/deadline → the same signature can be used indefinitely
        // BAD: no chainId/verifyingContract → it also works on the same contract on other chains
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == signer, "bad sig");

        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
