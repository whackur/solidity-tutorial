// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Concrete ERC-2771 forwarder. The EIP-712 domain name "MyForwarder"
///         is load-bearing — off-chain signers must use it when signing the
///         ForwardRequest.
contract MyForwarder is ERC2771Forwarder {
    constructor() ERC2771Forwarder("MyForwarder") {}
}

/// @notice Multi-tenant ERC-2771 challenge. A single MetaCounter is shared,
///         trusting one forwarder. Per-user state is keyed by the *recovered*
///         signer, not the direct caller.
///
///         Solve goal (per user):
///           1. Build a ForwardRequest calling increment(), with `from` = you.
///           2. Sign it with the forwarder's EIP-712 domain.
///           3. Call forwarder.execute(request) (anyone may relay it).
///         Because MetaCounter trusts the forwarder, increment() reads
///         _msgSender() as the signer (you), so counterOf[you] goes up — even
///         though the forwarder paid the gas and sent the actual transaction.
contract MetaCounter is ERC2771Context, SolvableBase {
    mapping(address account => uint256 count) public counterOf;
    address public lastSender;

    event Incremented(address indexed user, uint256 newCount);

    error MustGoThroughForwarder();

    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {}

    /// @notice Only counts when relayed through the trusted forwarder. A
    ///         direct EOA call reverts — the whole point is to learn the
    ///         meta-transaction path, not to call increment() yourself.
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
