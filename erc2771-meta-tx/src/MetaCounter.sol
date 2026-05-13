// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

/// @notice ERC-2771 aware target — recovers the original signer via {_msgSender}
///         when called by the trusted forwarder, otherwise behaves like a
///         normal contract.
contract MetaCounter is ERC2771Context {
    mapping(address account => uint256 count) public counterOf;
    address public lastCaller;

    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {}

    function increment() external {
        address user = _msgSender();
        unchecked {
            counterOf[user] += 1;
        }
        lastCaller = user;
    }
}
