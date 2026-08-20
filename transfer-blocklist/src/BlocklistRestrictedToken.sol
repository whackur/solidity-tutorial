// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AddressBlocklist} from "./AddressBlocklist.sol";

/// @notice Classroom ERC-20 whose normal transfers reject explicitly blocked endpoints.
contract BlocklistRestrictedToken is ERC20 {
    AddressBlocklist public immutable blocklist;

    error AddressBlocked(address account);

    constructor(AddressBlocklist blocklist_, address initialHolder, uint256 initialSupply)
        ERC20("Blocklist Restricted Token", "BLRT")
    {
        blocklist = blocklist_;
        _mint(initialHolder, initialSupply);
    }

    /// @notice Classroom faucet mint. Issuance is separate from holder transfers.
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            if (blocklist.isBlocked(from)) revert AddressBlocked(from);
            if (blocklist.isBlocked(to)) revert AddressBlocked(to);
        }
        super._update(from, to, value);
    }
}
