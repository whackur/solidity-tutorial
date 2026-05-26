// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Privileged registry whose admin setter is missing an `onlyOwner`
///         modifier. Anyone can promote any address to admin.
///
///         Multi-tenant grading is split into two steps so a malicious
///         caller cannot "force-solve" another user's slot:
///           1. `grantAdmin(account)` — buggy setter, no auth.
///           2. `claimAdmin()` — only the promoted user can flip the
///              final `solved[user]` flag for themselves.
///
///         A web UI polls `isSolved(user)`.
contract VulnerableRegistry is SolvableBase {
    address public immutable owner;

    mapping(address => bool) public adminPromoted;
    mapping(address => bool) public solved;

    event AdminGranted(address indexed account, address indexed by);
    event AdminClaimed(address indexed user);

    constructor() {
        owner = msg.sender;
    }

    /// @notice Intended to be admin-only (`require(msg.sender == owner)`),
    ///         but the modifier is missing. Anyone can call.
    function grantAdmin(address account) external {
        adminPromoted[account] = true;
        emit AdminGranted(account, msg.sender);
    }

    /// @notice Demonstrates proper auth — kept as contrast.
    function revokeAdmin(address account) external {
        require(msg.sender == owner, "not owner");
        adminPromoted[account] = false;
    }

    /// @notice User finalises their own solve. Required so a third party
    ///         calling `grantAdmin(victim)` cannot force-solve someone else.
    function claimAdmin() external {
        require(adminPromoted[msg.sender], "not promoted");
        solved[msg.sender] = true;
        emit AdminClaimed(msg.sender);
    }

    function isSolved(address user) public view override returns (bool) {
        return solved[user];
    }
}
