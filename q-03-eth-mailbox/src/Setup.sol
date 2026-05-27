// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Multi-tenant mailbox demonstrating the three ETH/calldata entry
///         points of a Solidity contract. A single instance is shared
///         across users; hits are tracked per msg.sender.
///
///         Trigger map:
///         - call with empty calldata + value  → receive()
///         - call with unknown selector        → fallback()
///         - call to receivePayable(bytes32)   → named function
contract Q03EthMailbox is SolvableBase {
    enum Trigger {
        None,
        Receive,
        Fallback,
        ReceivePayable
    }

    bytes4 private constant SET_FALLBACK_TAG_SELECTOR = bytes4(keccak256("setFallbackTag(bytes32)"));
    bytes4 private constant COUNT_FALLBACK_SELECTOR = bytes4(keccak256("countFallback()"));

    mapping(address => Trigger) public lastTrigger;
    mapping(address => bytes32) public lastTag;
    mapping(address => uint256) public lastValue;
    mapping(address => uint256) public fallbackHits;
    mapping(address => bool) public hitReceive;
    mapping(address => bool) public hitFallback;
    mapping(address => bool) public hitReceivePayable;

    event ReceiveHit(address indexed user, uint256 value);
    event FallbackHit(address indexed user, uint256 value, bytes32 tag);
    event ReceivePayableHit(address indexed user, uint256 value, bytes32 tag);

    receive() external payable {
        lastTrigger[msg.sender] = Trigger.Receive;
        lastValue[msg.sender] = msg.value;
        hitReceive[msg.sender] = true;
        emit ReceiveHit(msg.sender, msg.value);
    }

    fallback() external payable {
        lastTrigger[msg.sender] = Trigger.Fallback;
        lastValue[msg.sender] = msg.value;
        hitFallback[msg.sender] = true;

        bytes32 tag;
        if (msg.sig == SET_FALLBACK_TAG_SELECTOR) {
            require(msg.data.length == 36, "bad fallback payload");
            tag = abi.decode(msg.data[4:], (bytes32));
            lastTag[msg.sender] = tag;
        } else if (msg.sig == COUNT_FALLBACK_SELECTOR) {
            fallbackHits[msg.sender] += 1;
        }
        emit FallbackHit(msg.sender, msg.value, tag);
    }

    function receivePayable(bytes32 tag) external payable {
        lastTrigger[msg.sender] = Trigger.ReceivePayable;
        lastTag[msg.sender] = tag;
        lastValue[msg.sender] = msg.value;
        hitReceivePayable[msg.sender] = true;
        emit ReceivePayableHit(msg.sender, msg.value, tag);
    }

    function isSolved(address user) public view override returns (bool) {
        return hitReceive[user] && hitFallback[user] && hitReceivePayable[user];
    }
}
