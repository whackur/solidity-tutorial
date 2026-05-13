// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ReentrancyLab, VulnerableVault, ReentrancyAttacker} from "../src/Setup.sol";

contract Q09ReentrancyTest is Test {
    ReentrancyLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new ReentrancyLab();
        // Fund the lab so it can seed two vaults (Alice + Bob).
        vm.deal(address(lab), 100 ether);
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.prank(user);
        lab.createInstance();
        ReentrancyAttacker attacker = lab.attackerOf(user);

        vm.prank(user);
        attacker.attack{value: 1 ether}();
    }

    function test_AliceDrains() public {
        _solve(alice);

        VulnerableVault vault = lab.vaultOf(alice);
        ReentrancyAttacker attacker = lab.attackerOf(alice);

        assertEq(address(vault).balance, 0, "vault drained");
        assertGe(address(attacker).balance, 10 ether, "attacker holds bait + seed");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));

        // Each user got their own pair.
        assertTrue(lab.vaultOf(alice) != lab.vaultOf(bob));
        assertTrue(lab.attackerOf(alice) != lab.attackerOf(bob));

        // One user draining their own vault must not touch the other's.
        assertEq(address(lab.vaultOf(alice)).balance, 0);
        assertEq(address(lab.vaultOf(bob)).balance, 0);
    }

    function test_AttackerDrainsToOwner() public {
        _solve(alice);
        ReentrancyAttacker attacker = lab.attackerOf(alice);
        uint256 attackerBalance = address(attacker).balance;
        uint256 aliceBefore = alice.balance;

        vm.prank(alice);
        attacker.drain();

        assertEq(address(attacker).balance, 0);
        assertEq(alice.balance, aliceBefore + attackerBalance);
    }

    function test_NonOwnerAttackerCallReverts() public {
        vm.prank(alice);
        lab.createInstance();
        ReentrancyAttacker attacker = lab.attackerOf(alice);

        vm.deal(bob, 5 ether);
        vm.prank(bob);
        vm.expectRevert(bytes("only owner"));
        attacker.attack{value: 1 ether}();
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
