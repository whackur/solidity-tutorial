// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SolutionRef {
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
        token.permit(owner, address(this), value, deadline, v, r, s);
        IERC20(address(token)).transferFrom(owner, recipient, value);
    }
}
