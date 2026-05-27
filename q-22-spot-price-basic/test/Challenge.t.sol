// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q22SpotPriceBasicLab, Q22MockPool} from "../src/Setup.sol";

contract Q22SpotPriceBasicTest is Test {
    Q22SpotPriceBasicLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q22SpotPriceBasicLab();
    }

    function _solve(address user, uint256 amountIn) internal {
        vm.prank(user);
        lab.createInstance();

        Q22MockPool p = lab.poolOf(user);

        vm.prank(user);
        p.swapAForB(amountIn);
    }

    function test_AliceSolvesByDoublingReserveA() public {
        // Starting 1000:1000, spot = 1e18. Swapping ~414 A brings reserves
        // close to ~1414:707, spot ~ 0.5e18. Use 500 to clear the threshold
        // with margin.
        _solve(alice, 500e18);

        Q22MockPool p = lab.poolOf(alice);
        assertLe(p.getSpotPriceE18(), lab.TARGET_PRICE_E18());
        assertTrue(lab.isSolved(alice));
    }

    function test_SmallSwapDoesNotSolve() public {
        _solve(alice, 10e18);

        Q22MockPool p = lab.poolOf(alice);
        // Spot price moved (xy=k guarantees that), but not nearly enough.
        assertLt(p.getSpotPriceE18(), 1e18);
        assertGt(p.getSpotPriceE18(), lab.TARGET_PRICE_E18());
        assertFalse(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice, 500e18);
        _solve(bob, 500e18);

        // Each user owns their own pool — swapping in one does not move the other.
        Q22MockPool pa = lab.poolOf(alice);
        Q22MockPool pb = lab.poolOf(bob);
        assertTrue(address(pa) != address(pb));
        assertLe(pa.getSpotPriceE18(), lab.TARGET_PRICE_E18());
        assertLe(pb.getSpotPriceE18(), lab.TARGET_PRICE_E18());
        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
    }

    function test_NonOwnerSwapReverts() public {
        vm.prank(alice);
        lab.createInstance();

        Q22MockPool p = lab.poolOf(alice);
        vm.prank(bob);
        vm.expectRevert(Q22MockPool.OnlyOwner.selector);
        p.swapAForB(100e18);
    }

    function test_ZeroSwapReverts() public {
        vm.prank(alice);
        lab.createInstance();

        Q22MockPool p = lab.poolOf(alice);
        vm.prank(alice);
        vm.expectRevert(Q22MockPool.ZeroAmount.selector);
        p.swapAForB(0);
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }

    function test_AccumulatedSwapsAlsoWork() public {
        vm.prank(alice);
        lab.createInstance();
        Q22MockPool p = lab.poolOf(alice);

        // Two smaller swaps reach the target — xy=k is path-independent on
        // reserves (the *combined* trade gives the same end state as one).
        vm.startPrank(alice);
        p.swapAForB(250e18);
        p.swapAForB(250e18);
        vm.stopPrank();

        assertLe(p.getSpotPriceE18(), lab.TARGET_PRICE_E18());
        assertTrue(lab.isSolved(alice));
    }
}
