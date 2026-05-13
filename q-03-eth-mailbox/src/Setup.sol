// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @dev Local copy of ../tx-basics/src/EthMailbox.sol — kept self-contained.
contract EthMailbox {
    bytes4 private constant SET_FALLBACK_TAG_SELECTOR = bytes4(keccak256("setFallbackTag(bytes32)"));
    bytes4 private constant COUNT_FALLBACK_SELECTOR = bytes4(keccak256("countFallback()"));

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
    uint256 public fallbackHits;

    receive() external payable {
        lastTrigger = Trigger.Receive;
        lastValue = msg.value;
    }

    fallback() external payable {
        lastTrigger = Trigger.Fallback;
        lastValue = msg.value;
        lastCalldata = msg.data;

        if (msg.sig == SET_FALLBACK_TAG_SELECTOR) {
            require(msg.data.length == 36, "bad fallback payload");
            lastTag = abi.decode(msg.data[4:], (bytes32));
        } else if (msg.sig == COUNT_FALLBACK_SELECTOR) {
            fallbackHits += 1;
        }
    }

    function receivePayable(bytes32 tag) external payable {
        lastTrigger = Trigger.ReceivePayable;
        lastTag = tag;
        lastValue = msg.value;
    }
}
