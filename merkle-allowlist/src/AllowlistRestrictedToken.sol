// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MerkleAllowlist} from "./MerkleAllowlist.sol";

/**
 * @title AllowlistRestrictedToken
 * @notice A deliberately small teaching token that checks both parties against
 *         a MerkleAllowlist before allowing a transfer.
 *
 *         This demonstrates the transfer-gate concept. It is not an ERC-3643
 *         implementation and must not be used as a complete compliance system.
 */
contract AllowlistRestrictedToken is ERC20 {
    MerkleAllowlist public immutable allowlist;

    error AddressNotAllowed(address account);

    constructor(MerkleAllowlist allowlist_, address initialHolder, uint256 initialSupply)
        ERC20("Allowlist Restricted Token", "ALRT")
    {
        allowlist = allowlist_;
        _mint(initialHolder, initialSupply);
    }

    /// @notice Classroom faucet mint. Issuance is visible but not a holder-to-holder transfer.
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            if (!allowlist.isAllowed(from)) revert AddressNotAllowed(from);
            if (!allowlist.isAllowed(to)) revert AddressNotAllowed(to);
        }
        super._update(from, to, value);
    }
}
