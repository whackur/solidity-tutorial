// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Public-faucet ERC-20 with EIP-2612 permit. Any address can mint
///         themselves a balance to play with.
contract Q06PermitToken is ERC20, ERC20Permit {
    constructor() ERC20("Q06PermitToken", "PT") ERC20Permit("Q06PermitToken") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Multi-tenant permit challenge. A single instance is shared.
///         Each user signs an EIP-2612 permit off-chain authorising this
///         challenge contract as the spender, then submits the signed
///         permit + a transfer-from in one tx.
///
///         Progress is keyed by the *signer* (permit `owner`), which is
///         the user's EOA. isSolved(user) becomes true after the user
///         consumes at least one permit and a non-zero pull moves tokens.
contract Q06PermitChallenge is SolvableBase {
    Q06PermitToken public immutable token;

    mapping(address => bool) public usedPermit;

    event PermitSpent(address indexed owner, uint256 value, address indexed recipient);

    constructor(Q06PermitToken t) {
        token = t;
    }

    /// @notice Submit a signed EIP-2612 permit for the caller's tokens and
    ///         immediately transferFrom to a recipient of the caller's choice.
    /// @param owner     The token holder & permit signer (typically the user).
    /// @param value     Allowance + transfer amount in token units.
    /// @param deadline  Permit deadline (unix seconds).
    /// @param v, r, s   ECDSA components of the signed permit.
    /// @param recipient Where the pulled tokens land.
    function spendWithPermit(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address recipient
    ) external {
        require(value > 0, "value must be > 0");
        IERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);
        require(IERC20(address(token)).transferFrom(owner, recipient, value), "transferFrom failed");
        usedPermit[owner] = true;
        emit PermitSpent(owner, value, recipient);
    }

    function isSolved(address user) public view override returns (bool) {
        return usedPermit[user] && token.nonces(user) > 0;
    }
}
