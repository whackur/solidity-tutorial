// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q19ReentrancyBasicLab, Q19VulnerableMiniVault, Q19BasicAttacker} from "../src/Setup.sol";

contract Q19ReentrancyBasicTest is Test {
    Q19ReentrancyBasicLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q19ReentrancyBasicLab();
        // Fund the lab so it can seed two vaults (Alice + Bob) plus bait.
        vm.deal(address(lab), 100 ether);
    }

    function _solve(address user) internal {
        vm.prank(user);
        lab.createInstance();

        Q19BasicAttacker attacker = lab.attackerOf(user);

        // Student call sequence is exactly two transactions: createInstance + attack.
        // attack() is non-payable in this beginner lab; bait was pre-funded by the lab.
        vm.prank(user);
        attacker.attack();
    }

    function test_AliceDrainsWithTwoCalls() public {
        _solve(alice);

        Q19VulnerableMiniVault vault = lab.vaultOf(alice);
        Q19BasicAttacker attacker = lab.attackerOf(alice);

        assertEq(address(vault).balance, 0, "vault drained");
        assertGe(address(attacker).balance, 5 ether, "attacker holds at least the seed");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));

        // Each user got their own pair.
        assertTrue(address(lab.vaultOf(alice)) != address(lab.vaultOf(bob)));
        assertTrue(address(lab.attackerOf(alice)) != address(lab.attackerOf(bob)));

        // One user draining their own vault must not touch the other's.
        assertEq(address(lab.vaultOf(alice)).balance, 0);
        assertEq(address(lab.vaultOf(bob)).balance, 0);
    }

    function test_AttackerDrainsToOwner() public {
        _solve(alice);
        Q19BasicAttacker attacker = lab.attackerOf(alice);
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
        Q19BasicAttacker attacker = lab.attackerOf(alice);

        vm.prank(bob);
        vm.expectRevert(bytes("only owner"));
        attacker.attack();
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }

    function test_LabUnderfundedReverts() public {
        Q19ReentrancyBasicLab freshLab = new Q19ReentrancyBasicLab();
        // No vm.deal — lab has 0 balance.
        vm.prank(alice);
        vm.expectRevert(bytes("lab underfunded"));
        freshLab.createInstance();
    }
}
