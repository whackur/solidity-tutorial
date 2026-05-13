// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleWallet} from "./Setup.sol";

contract Solution {
    /// @notice Deposit `msg.value` ETH and this contract's full token balance into `w`.
    function depositAll(SimpleWallet w, IERC20 token) external payable {
        // TODO: 1) forward msg.value via w.depositEth{value: msg.value}()
        //       2) approve `w` for token.balanceOf(address(this))
        //       3) w.depositErc20(address(token), bal);
        w; token;
        revert("Solution.depositAll: not implemented");
    }

    /// @notice Withdraw half of `originalAmount` tokens back from `w` to this contract.
    function withdrawHalfTokens(SimpleWallet w, IERC20 token, uint256 originalAmount) external {
        // TODO: w.withdrawErc20(address(token), originalAmount / 2);
        w; token; originalAmount;
        revert("Solution.withdrawHalfTokens: not implemented");
    }

    receive() external payable {}
}
