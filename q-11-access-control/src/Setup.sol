// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Privileged registry used to study function-level authorization.
///         Multi-tenant grading is split so a caller cannot force-complete
///         another user's slot. A web UI polls `isSolved(user)`.
contract Q11VulnerableRegistry is SolvableBase {
    address public immutable owner;

    mapping(address => bool) public adminPromoted;
    mapping(address => bool) public solved;

    event AdminGranted(address indexed account, address indexed by);
    event AdminClaimed(address indexed user);

    constructor() {
        owner = msg.sender;
    }

    /// @notice State-changing admin path used by the exercise.
    function grantAdmin(address account) external {
        adminPromoted[account] = true;
        emit AdminGranted(account, msg.sender);
    }

    /// @notice Demonstrates an owner-guarded admin path.
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
