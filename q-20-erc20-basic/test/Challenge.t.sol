// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Erc20BasicLab, Faucet, PullVault} from "../src/Setup.sol";

contract Q20Erc20BasicTest is Test {
    Erc20BasicLab internal lab;
    Faucet internal faucet;
    PullVault internal vault;

    // Cached so we never call `lab.TARGET()` while a `vm.prank` is active —
    // any external call before the prank target consumes the prank.
    uint256 internal TARGET;
    uint256 internal CLAIM_AMOUNT;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Erc20BasicLab();
        faucet = lab.faucet();
        vault = lab.vault();
        TARGET = lab.TARGET();
        CLAIM_AMOUNT = faucet.CLAIM_AMOUNT();
    }

    function _solve(address user) internal {
        // 1. Claim the faucet.
        vm.prank(user);
        faucet.claim();

        // 2. Approve the vault for at least TARGET tokens.
        vm.prank(user);
        faucet.approve(address(vault), TARGET);

        // 3. Vault pulls tokens via transferFrom (the user is the caller; the
        //    vault is the spender — this only works because of step 2).
        vm.prank(user);
        vault.pull(TARGET);
    }

    function test_AliceSolvesWithThreeCalls() public {
        _solve(alice);

        assertTrue(lab.isSolved(alice));
        assertEq(faucet.balanceOf(alice), CLAIM_AMOUNT - TARGET);
        assertEq(faucet.balanceOf(address(vault)), TARGET);
        assertEq(vault.deposited(alice), TARGET);
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));

        // Each user owns their own balance and deposited tally.
        assertEq(faucet.balanceOf(alice), CLAIM_AMOUNT - TARGET);
        assertEq(faucet.balanceOf(bob), CLAIM_AMOUNT - TARGET);
        assertEq(vault.deposited(alice), TARGET);
        assertEq(vault.deposited(bob), TARGET);

        // The vault now holds twice TARGET in total — combined across users.
        assertEq(faucet.balanceOf(address(vault)), TARGET * 2);
    }

    function test_ClaimTwiceReverts() public {
        vm.startPrank(alice);
        faucet.claim();
        vm.expectRevert(bytes("already claimed"));
        faucet.claim();
        vm.stopPrank();
    }

    function test_PullWithoutApproveReverts() public {
        vm.prank(alice);
        faucet.claim();

        vm.prank(alice);
        vm.expectRevert(bytes("allowance"));
        vault.pull(TARGET);
    }

    function test_PullMoreThanApprovedReverts() public {
        vm.startPrank(alice);
        faucet.claim();
        faucet.approve(address(vault), 1e18);
        vm.expectRevert(bytes("allowance"));
        vault.pull(2e18);
        vm.stopPrank();
    }

    function test_AllowanceIsConsumedOnPull() public {
        vm.startPrank(alice);
        faucet.claim();
        faucet.approve(address(vault), TARGET);
        vault.pull(TARGET);
        vm.stopPrank();

        // After the pull the remaining allowance is zero.
        assertEq(faucet.allowance(alice, address(vault)), 0);
    }

    function test_BeforeAnyActionIsSolvedFalse() public view {
        assertFalse(lab.isSolved(alice));
    }
}
