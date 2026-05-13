// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleWallet, MockERC20} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q05WalletTest is Test {
    SimpleWallet internal w;
    MockERC20 internal token;
    Solution internal sol;

    uint256 internal constant TOKEN_AMOUNT = 100e18;

    function setUp() public {
        w = new SimpleWallet();
        token = new MockERC20();
        sol = new Solution();
        vm.deal(address(this), 5 ether);
        token.mint(address(sol), TOKEN_AMOUNT);
    }

    function test_DepositMovesEth() public {
        sol.depositAll{value: 1 ether}(w, IERC20(address(token)));
        assertEq(address(w).balance, 1 ether, "wallet holds the ETH");
    }

    function test_DepositMovesTokens() public {
        sol.depositAll{value: 1 ether}(w, IERC20(address(token)));
        assertEq(token.balanceOf(address(w)), TOKEN_AMOUNT, "wallet holds tokens");
        assertEq(token.balanceOf(address(sol)), 0, "solution emptied");
    }

    function test_WithdrawHalfTokens() public {
        sol.depositAll{value: 1 ether}(w, IERC20(address(token)));
        sol.withdrawHalfTokens(w, IERC20(address(token)), TOKEN_AMOUNT);
        assertEq(token.balanceOf(address(w)), TOKEN_AMOUNT / 2, "half left in wallet");
        assertEq(token.balanceOf(address(sol)), TOKEN_AMOUNT / 2, "half returned");
    }
}
