// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/// @title RoleBasedERC20 — role-separated ERC-20 using AccessControlEnumerable
/// @notice
///   Production tokens rarely hand every privilege to a single Ownable owner.
///   Instead they split duties into roles managed by AccessControl:
///   - DEFAULT_ADMIN_ROLE : grants/revokes every other role (often a multisig)
///   - MINTER_ROLE        : can mint new supply (e.g. a bridge or vesting contract)
///   - PAUSER_ROLE        : can pause/unpause transfers (e.g. an incident-response bot)
/// @dev
///   AccessControlEnumerable layers an EnumerableSet.AddressSet per role on top
///   of plain AccessControl, so membership is enumerable on-chain:
///   `getRoleMemberCount(role)` / `getRoleMember(role, index)` / `getRoleMembers(role)`.
///   Plain AccessControl only answers `hasRole(role, account)` — you must already
///   know the address. Enumerability costs extra gas on grant/revoke (set
///   bookkeeping) but lets indexers, dashboards, and audits list every holder of
///   a role without replaying historical events.
contract RoleBasedERC20 is ERC20, ERC20Pausable, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @param admin receives DEFAULT_ADMIN_ROLE plus the two operational roles.
    ///        In production the admin is typically a multisig and the
    ///        operational roles are granted to separate, narrower accounts.
    constructor(address admin) ERC20("RoleToken", "RLT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ------------------------------------------------------------------
    // Multi-inheritance override — ERC20 and ERC20Pausable both define _update
    // ------------------------------------------------------------------

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
