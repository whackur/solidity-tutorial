// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Concrete ERC-2771 forwarder. The EIP-712 domain name "Q26MyForwarder"
///         is load-bearing — off-chain signers must use it when signing the
///         ForwardRequest.
contract Q26MyForwarder is ERC2771Forwarder {
    constructor() ERC2771Forwarder("Q26MyForwarder") {}
}

/// @notice Multi-tenant ERC-2771 challenge. A single Q26MetaCounter is shared,
///         trusting one forwarder. Per-user state is keyed by the *recovered*
///         signer, not the direct caller.
///
///         The exercise focuses on ERC-2771 sender recovery through a trusted
///         forwarder and EIP-712 request validation.
contract Q26MetaCounter is ERC2771Context, SolvableBase {
    mapping(address account => uint256 count) public counterOf;
    address public lastSender;

    event Incremented(address indexed user, uint256 newCount);

    error MustGoThroughForwarder();

    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {}

    /// @notice Counts only when the trusted forwarder supplies the recovered
    ///         sender context.
    function increment() external {
        if (!isTrustedForwarder(msg.sender)) revert MustGoThroughForwarder();
        address user = _msgSender();
        unchecked {
            counterOf[user] += 1;
        }
        lastSender = user;
        emit Incremented(user, counterOf[user]);
    }

    function isSolved(address user) public view override returns (bool) {
        return counterOf[user] > 0;
    }
}
