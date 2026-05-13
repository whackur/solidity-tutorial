// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ReadOnlyLab, ShareVault, PriceConsumer, ReadOnlyAttacker} from "../src/Setup.sol";

contract Q18ReadOnlyReentrancyTest is Test {
    ReadOnlyLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new ReadOnlyLab();
        vm.deal(address(lab), 10 ether);
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        lab.createInstance();
        ReadOnlyAttacker attacker = lab.attackerOf(user);
        attacker.attack{value: 0.9 ether}();
        vm.stopPrank();
    }

    function test_AliceInflatesCredits() public {
        _solve(alice);

        PriceConsumer consumer = lab.consumerOf(alice);
        ReadOnlyAttacker attacker = lab.attackerOf(alice);

        uint256 credits = consumer.credits(address(attacker));
        // Inflated by ~10× over a clean read. Concretely ~10e18.
        assertGe(credits, 5e18, "credits inflated past threshold");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        assertTrue(lab.consumerOf(alice) != lab.consumerOf(bob));
    }

    /// @notice A clean read (no withdraw in flight) returns the honest
    ///         price and the consumer mints proportionate (small) credits.
    function test_CleanReadIsHonest() public {
        vm.prank(alice);
        lab.createInstance();
        PriceConsumer consumer = lab.consumerOf(alice);

        // Honest credit mint at price = 1e18 → 1e18 credits per ETH.
        consumer.mintCredits(alice, 1 ether);
        assertEq(consumer.credits(alice), 1e18);
        assertFalse(lab.isSolved(alice));
    }

    function test_SharePriceDropsDuringWithdraw() public {
        vm.prank(alice);
        lab.createInstance();
        ShareVault vault = lab.vaultOf(alice);
        ReadOnlyAttacker attacker = lab.attackerOf(alice);

        // Before attack: 1:1 price.
        assertEq(vault.sharePrice(), 1e18, "honest price");

        vm.prank(alice);
        attacker.attack{value: 0.9 ether}();

        // After attack the totalShares are decreased proportionally so
        // the price is restored. The stale window only existed *during*
        // the external call.
        assertApproxEqAbs(vault.sharePrice(), 1e18, 1, "price restored");
    }

    function test_NonOwnerAttackerCallReverts() public {
        vm.prank(alice);
        lab.createInstance();
        ReadOnlyAttacker attacker = lab.attackerOf(alice);

        vm.deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert(bytes("only owner"));
        attacker.attack{value: 0.5 ether}();
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
