// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @dev Local copy of ../vulnerabilities/src/signature-replay/VulnerableSigClaim.sol
contract VulnerableSigClaim {
    address public immutable signer;

    constructor(address s) {
        signer = s;
    }

    function claim(address payable to, uint256 amount, bytes calldata signature) external {
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == signer, "bad sig");

        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}

interface IVulnerableSigClaim {
    function claim(address payable to, uint256 amount, bytes calldata signature) external;
}
