// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Storage-recording recipient that distinguishes the three entry paths
///         a value-bearing call can take: the unnamed `receive`, the unnamed
///         `fallback`, and a named payable function.
///
/// @dev Each handler writes storage, so calls reaching {receive} or {fallback}
///      via the 2300-gas stipend (`transfer` / `send`) will run out of gas and
///      revert at the SSTORE — see {EthSender} tests for the demonstration.
contract EthMailbox {
    enum Trigger {
        None,
        Receive,
        Fallback,
        ReceivePayable
    }

    Trigger public lastTrigger;
    bytes32 public lastTag;
    bytes public lastCalldata;
    uint256 public lastValue;

    /// @dev Hit by value-bearing calls with empty calldata.
    receive() external payable {
        lastTrigger = Trigger.Receive;
        lastValue = msg.value;
    }

    /// @dev Hit by calls whose selector matches no named function (or by
    ///      non-empty calldata when no `receive` exists).
    fallback() external payable {
        lastTrigger = Trigger.Fallback;
        lastValue = msg.value;
        lastCalldata = msg.data;
    }

    /// @dev Named payable function — wins selector dispatch over
    ///      `receive`/`fallback` whenever the calldata's first 4 bytes match.
    function receivePayable(bytes32 tag) external payable {
        lastTrigger = Trigger.ReceivePayable;
        lastTag = tag;
        lastValue = msg.value;
    }
}
