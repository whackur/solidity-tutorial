// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {EthMailbox} from "../src/Setup.sol";

contract SolutionRef {
    function triggerReceive(EthMailbox mb) external payable {
        (bool ok,) = address(mb).call{value: msg.value}("");
        require(ok, "receive call failed");
    }

    function triggerFallbackWithTag(EthMailbox mb, bytes32 tag) external payable {
        bytes memory data = abi.encodeWithSignature("setFallbackTag(bytes32)", tag);
        (bool ok,) = address(mb).call{value: msg.value}(data);
        require(ok, "fallback call failed");
    }

    function triggerReceivePayable(EthMailbox mb, bytes32 tag) external payable {
        mb.receivePayable{value: msg.value}(tag);
    }

    receive() external payable {}
}
