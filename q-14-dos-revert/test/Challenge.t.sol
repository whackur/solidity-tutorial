// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q14DosLab, Q14KingOfHill, Q14RevertKing} from "../src/Setup.sol";

contract Q14DosRevertTest is Test {
    Q14DosLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        lab = new Q14DosLab();
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
        vm.deal(carol, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        lab.createInstance();
        Q14KingOfHill king = lab.kingOf(user);
        Q14RevertKing attacker = lab.attackerOf(user);

        // Opening bid from the user (EOA — accepts refunds fine).
        king.bid{value: 0.01 ether}();
        // Take the throne via the reverting attacker.
        attacker.takeThrone{value: 0.02 ether}();
        vm.stopPrank();
    }

    function test_AliceLocksThrone() public {
        _solve(alice);
        Q14KingOfHill king = lab.kingOf(alice);
        Q14RevertKing attacker = lab.attackerOf(alice);
        assertEq(king.currentKing(), address(attacker));
        assertTrue(lab.isSolved(alice));
    }

    /// @notice After the takeover, NO ONE can outbid — proving the DoS.
    function test_OutbidAttemptReverts() public {
        _solve(alice);
        Q14KingOfHill king = lab.kingOf(alice);

        vm.prank(carol);
        vm.expectRevert(bytes("refund failed"));
        king.bid{value: 1 ether}();
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        assertTrue(lab.kingOf(alice) != lab.kingOf(bob));
        assertTrue(lab.attackerOf(alice) != lab.attackerOf(bob));
    }

    function test_NonOwnerAttackerCallReverts() public {
        vm.prank(alice);
        lab.createInstance();
        Q14RevertKing attacker = lab.attackerOf(alice);

        vm.deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert(bytes("only owner"));
        attacker.takeThrone{value: 0.5 ether}();
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
