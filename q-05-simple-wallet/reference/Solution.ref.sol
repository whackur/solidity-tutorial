// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleWallet} from "../src/Setup.sol";

contract SolutionRef {
    function depositAll(SimpleWallet w, IERC20 token) external payable {
        w.depositEth{value: msg.value}();
        uint256 bal = token.balanceOf(address(this));
        token.approve(address(w), bal);
        w.depositErc20(address(token), bal);
    }

    function withdrawHalfTokens(SimpleWallet w, IERC20 token, uint256 originalAmount) external {
        w.withdrawErc20(address(token), originalAmount / 2);
    }

    receive() external payable {}
}
