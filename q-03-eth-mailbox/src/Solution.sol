// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {EthMailbox} from "./Setup.sol";

contract Solution {
    /// @notice Cause `mb.lastTrigger()` to become Receive. Forward msg.value.
    function triggerReceive(EthMailbox mb) external payable {
        // TODO: low-level call with EMPTY calldata + forward msg.value.
        //       Hint: (bool ok, ) = address(mb).call{value: msg.value}("");
        mb;
        revert("Solution.triggerReceive: not implemented");
    }

    /// @notice Cause `mb.lastTrigger()` to become Fallback AND `mb.lastTag()` to equal `tag`.
    function triggerFallbackWithTag(EthMailbox mb, bytes32 tag) external payable {
        // TODO: build calldata for the FAKE selector "setFallbackTag(bytes32)" plus the tag,
        //       then call with msg.value.
        //       Hint: bytes memory data = abi.encodeWithSignature("setFallbackTag(bytes32)", tag);
        mb; tag;
        revert("Solution.triggerFallbackWithTag: not implemented");
    }

    /// @notice Cause `mb.lastTrigger()` to become ReceivePayable AND `mb.lastTag()` to equal `tag`.
    function triggerReceivePayable(EthMailbox mb, bytes32 tag) external payable {
        // TODO: typed call to the named payable function.
        //       Hint: mb.receivePayable{value: msg.value}(tag);
        mb; tag;
        revert("Solution.triggerReceivePayable: not implemented");
    }

    receive() external payable {}
}
