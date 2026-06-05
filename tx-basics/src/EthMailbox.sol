// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Storage-recording recipient that distinguishes the three entry paths
///         a value-bearing call can take: the unnamed `receive`, the unnamed
///         `fallback`, and a named payable function.
///
///         All recordings are keyed by `msg.sender` so many students can share
///         one deployment without overwriting each other's observations.
///
/// @dev Each handler writes storage, so calls reaching {receive} or {fallback}
///      via the 2300-gas stipend (`transfer` / `send`) will run out of gas and
///      revert at the SSTORE — see {EthSender} tests for the demonstration.
contract EthMailbox {
    bytes4 private constant SET_FALLBACK_TAG_SELECTOR = bytes4(keccak256("setFallbackTag(bytes32)"));
    bytes4 private constant COUNT_FALLBACK_SELECTOR = bytes4(keccak256("countFallback()"));

    enum Trigger {
        None,
        Receive,
        Fallback,
        ReceivePayable
    }

    mapping(address => Trigger) public lastTrigger;
    mapping(address => bytes32) public lastTag;
    mapping(address => bytes) public lastCalldata;
    mapping(address => uint256) public lastValue;
    mapping(address => uint256) public fallbackHits;

    /// @dev Hit by value-bearing calls with empty calldata.
    receive() external payable {
        lastTrigger[msg.sender] = Trigger.Receive;
        lastValue[msg.sender] = msg.value;
    }

    /// @dev Hit by calls whose selector matches no named function. Besides
    ///      recording raw calldata, this demonstrates how a fallback can route
    ///      specific unknown selectors to different behavior.
    fallback() external payable {
        lastTrigger[msg.sender] = Trigger.Fallback;
        lastValue[msg.sender] = msg.value;
        lastCalldata[msg.sender] = msg.data;

        if (msg.sig == SET_FALLBACK_TAG_SELECTOR) {
            require(msg.data.length == 36, "bad fallback payload");
            lastTag[msg.sender] = abi.decode(msg.data[4:], (bytes32));
        } else if (msg.sig == COUNT_FALLBACK_SELECTOR) {
            fallbackHits[msg.sender] += 1;
        }
    }

    /// @dev Named payable function — wins selector dispatch over
    ///      `receive`/`fallback` whenever the calldata's first 4 bytes match.
    function receivePayable(bytes32 tag) external payable {
        lastTrigger[msg.sender] = Trigger.ReceivePayable;
        lastTag[msg.sender] = tag;
        lastValue[msg.sender] = msg.value;
    }
}
