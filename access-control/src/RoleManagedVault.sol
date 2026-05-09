// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title RoleManagedVault — *a company with split departmental privileges*
/// @notice
///   - DEFAULT_ADMIN_ROLE : grants/revokes other roles (policy manager only)
///   - MINTER_ROLE        : mint only
///   - PAUSER_ROLE        : pause / unpause only
/// Compare against OwnableVault, where one address holds every privilege at once.
contract RoleManagedVault is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(address => uint256) public balanceOf;
    bool public paused;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(!paused, "paused");
        balanceOf[to] += amount;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        paused = false;
    }
}
