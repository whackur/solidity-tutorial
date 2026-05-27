// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Q05SimpleWallet, Q05MockERC20} from "../src/Setup.sol";

contract Q05WalletTest is Test {
    Q05SimpleWallet internal wallet;
    Q05MockERC20 internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal constant TOKEN_AMOUNT = 100e18;

    function setUp() public {
        wallet = new Q05SimpleWallet();
        token = new Q05MockERC20();
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        // ETH deposit + withdraw
        vm.startPrank(user);
        wallet.depositEth{value: 1 ether}();
        wallet.withdrawEth(0.5 ether);

        // ERC20 mint + approve + deposit + withdraw
        token.mint(user, TOKEN_AMOUNT);
        token.approve(address(wallet), TOKEN_AMOUNT);
        wallet.depositErc20(address(token), TOKEN_AMOUNT);
        wallet.withdrawErc20(address(token), TOKEN_AMOUNT / 2);
        vm.stopPrank();
    }

    function test_AliceSolves() public {
        _solve(alice);

        assertTrue(wallet.depositedEth(alice));
        assertTrue(wallet.withdrewEth(alice));
        assertTrue(wallet.depositedErc20(alice));
        assertTrue(wallet.withdrewErc20(alice));
        assertTrue(wallet.isSolved(alice));

        assertEq(wallet.ethBalanceOf(alice), 0.5 ether);
        assertEq(wallet.erc20BalanceOf(alice, address(token)), TOKEN_AMOUNT / 2);
        assertEq(token.balanceOf(alice), TOKEN_AMOUNT / 2);
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(wallet.isSolved(alice));
        assertTrue(wallet.isSolved(bob));

        // Per-user balance isolation.
        assertEq(wallet.ethBalanceOf(alice), 0.5 ether);
        assertEq(wallet.ethBalanceOf(bob), 0.5 ether);
        assertEq(wallet.erc20BalanceOf(alice, address(token)), TOKEN_AMOUNT / 2);
        assertEq(wallet.erc20BalanceOf(bob, address(token)), TOKEN_AMOUNT / 2);
    }

    function test_PartialProgressDoesNotSolve() public {
        vm.startPrank(alice);
        wallet.depositEth{value: 1 ether}();
        // Skipping withdraw + ERC20 path.
        vm.stopPrank();
        assertFalse(wallet.isSolved(alice));
    }

    function test_DirectTransferTriggersDeposit() public {
        vm.prank(alice);
        (bool ok,) = address(wallet).call{value: 1 ether}("");
        require(ok, "transfer failed");
        assertEq(wallet.ethBalanceOf(alice), 1 ether);
        assertTrue(wallet.depositedEth(alice));
    }

    function test_OverWithdrawReverts() public {
        vm.startPrank(alice);
        wallet.depositEth{value: 1 ether}();
        vm.expectRevert(bytes("Insufficient ETH balance"));
        wallet.withdrawEth(2 ether);
        vm.stopPrank();
    }
}
