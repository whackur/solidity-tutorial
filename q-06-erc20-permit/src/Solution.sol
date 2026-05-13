// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract Solution {
    /// @notice Consume an EIP-2612 permit and immediately pull the tokens out.
    function pullWithPermit(
        IERC20Permit token,
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address recipient
    ) external {
        // TODO: 1) token.permit(owner, address(this), value, deadline, v, r, s);
        //       2) IERC20(address(token)).transferFrom(owner, recipient, value);
        token; owner; value; deadline; v; r; s; recipient;
        revert("Solution.pullWithPermit: not implemented");
    }
}
