// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {AllowanceToken} from "../src/AllowanceToken.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @title AllowanceFlowTest — step-by-step walkthrough of the ERC-20 four-function cycle.
///
/// Sequence: transfer → transferFrom-without-approve (revert) → approve → allowance check
///           → deposit (transferFrom) → allowance decrements → infinite approval → withdraw
contract AllowanceFlowTest is Test {
    AllowanceToken internal token;
    TokenBank internal bank;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        // Deploy token; mint initial supply to this test contract.
        token = new AllowanceToken("AllowanceToken", "ATK", 1_000_000 ether);
        bank = new TokenBank(token);

        // Fund alice with 500 ATK for the flow below.
        token.mint(alice, 500 ether);
    }

    // -------------------------------------------------------------------------
    // (a) direct transfer moves balance
    // -------------------------------------------------------------------------
    function test_a_DirectTransferMovesBalance() public {
        // alice sends 10 ATK directly to bob via transfer (no allowance involved).
        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
        assertEq(token.balanceOf(alice), 490 ether);
    }

    // -------------------------------------------------------------------------
    // (b) deposit (transferFrom) WITHOUT approve reverts
    // -------------------------------------------------------------------------
    function test_b_DepositWithoutApproveReverts() public {
        // The bank tries to pull alice's tokens but alice gave no allowance — must revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(bank), // spender
                0, // current allowance
                60 ether // required amount
            )
        );
        vm.prank(alice);
        bank.deposit(60 ether);
    }

    // -------------------------------------------------------------------------
    // (c) approve sets allowance
    // -------------------------------------------------------------------------
    function test_c_ApproveGrantsAllowance() public {
        vm.prank(alice);
        token.approve(address(bank), 100 ether);

        // allowance(owner, spender) reflects the granted budget.
        assertEq(token.allowance(alice, address(bank)), 100 ether);
    }

    // -------------------------------------------------------------------------
    // (d) deposit(60e18) succeeds and decrements allowance to 40e18
    // Numbers are fixed (100/60/40) — mirrored in the lecture slides.
    // -------------------------------------------------------------------------
    function test_d_DepositDecreasesAllowance() public {
        vm.startPrank(alice);
        token.approve(address(bank), 100 ether);

        bank.deposit(60 ether);
        vm.stopPrank();

        // Bank received the tokens and credited alice's balance.
        assertEq(bank.balances(alice), 60 ether);
        assertEq(token.balanceOf(address(bank)), 60 ether);
        assertEq(token.balanceOf(alice), 440 ether);

        // Remaining allowance: 100 - 60 = 40.
        assertEq(token.allowance(alice, address(bank)), 40 ether);
    }

    // -------------------------------------------------------------------------
    // (e) infinite approval (type(uint256).max) does NOT decrement on transferFrom
    // -------------------------------------------------------------------------
    function test_e_InfiniteApprovalNotDecremented() public {
        vm.startPrank(alice);
        token.approve(address(bank), type(uint256).max);
        bank.deposit(60 ether);
        vm.stopPrank();

        // OZ ERC20 leaves max allowance unchanged (infinite-approval convention).
        assertEq(token.allowance(alice, address(bank)), type(uint256).max);
    }

    // -------------------------------------------------------------------------
    // (f) withdraw returns tokens via plain transfer (no allowance needed)
    // -------------------------------------------------------------------------
    function test_f_WithdrawReturnsTokens() public {
        vm.startPrank(alice);
        token.approve(address(bank), 100 ether);
        bank.deposit(60 ether);
        bank.withdraw(60 ether);
        vm.stopPrank();

        // Alice gets her tokens back; bank balance returns to zero.
        assertEq(bank.balances(alice), 0);
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.balanceOf(address(bank)), 0);
    }
}
