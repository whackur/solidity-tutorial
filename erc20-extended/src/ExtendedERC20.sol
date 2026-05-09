// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ExtendedERC20 — five common ERC-20 extensions combined in one contract
/// @notice
///   - Burnable : holders burn from their own balance (`burn` / `burnFrom`)
///   - Capped   : minting blocked beyond `cap_`
///   - Pausable : owner can pause/unpause every transfer
///   - Permit   : EIP-2612 — gasless approve via signature (1 tx for approve+transferFrom)
///   - Votes    : balance → voting power, with checkpoints that defeat flash-loan governance attacks
/// @dev Multiple-inheritance pitfalls:
///   `_update` is overridden by ERC20 / ERC20Capped / ERC20Pausable / ERC20Votes — explicit multi-override required
///   `nonces` is defined in both ERC20Permit and Nonces — explicit multi-override required
contract ExtendedERC20 is
    ERC20,
    ERC20Burnable,
    ERC20Capped,
    ERC20Pausable,
    ERC20Permit,
    ERC20Votes,
    Ownable
{
    constructor(address initialOwner, uint256 cap_)
        ERC20("ExtendedToken", "EXT")
        ERC20Capped(cap_)
        ERC20Permit("ExtendedToken")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ------------------------------------------------------------------
    // Multi-inheritance overrides — _update / nonces
    // ------------------------------------------------------------------

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Capped, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
