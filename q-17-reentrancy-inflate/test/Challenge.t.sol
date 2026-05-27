// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q17InflateLab, Q17YieldVault, Q17InflateAttacker, Q17InflateHelper} from "../src/Setup.sol";

contract Q17ReentrancyInflateTest is Test {
    Q17InflateLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q17InflateLab();
        vm.deal(address(lab), 100 ether);
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        lab.createInstance();
        Q17InflateAttacker attacker = lab.attackerOf(user);
        Q17InflateHelper helper = lab.helperOf(user);

        attacker.attack{value: 1 ether}();   // outer withdraw + cross-function transfer
        helper.pull();                       // second payout
        vm.stopPrank();
    }

    function test_AliceInflates() public {
        _solve(alice);

        Q17YieldVault vault = lab.vaultOf(alice);
        Q17InflateAttacker attacker = lab.attackerOf(alice);
        Q17InflateHelper helper = lab.helperOf(alice);

        assertEq(address(vault).balance, 0, "vault drained");
        assertEq(address(attacker).balance, 1 ether, "attacker paid once");
        assertEq(address(helper).balance, 1 ether, "helper paid once (the inflate)");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        assertTrue(lab.vaultOf(alice) != lab.vaultOf(bob));
    }

    /// @notice A clean deposit-then-withdraw (no helper trick) only
    ///         returns the bait — nothing is inflated.
    function test_NoCrossFunctionLeavesSeedAlone() public {
        vm.startPrank(alice);
        lab.createInstance();
        Q17YieldVault vault = lab.vaultOf(alice);

        vault.deposit{value: 1 ether}();
        vault.withdraw();
        vm.stopPrank();

        assertEq(address(vault).balance, 1 ether, "seed untouched");
        assertFalse(lab.isSolved(alice));
    }

    function test_DrainForwardsToOwner() public {
        _solve(alice);
        uint256 aliceBefore = alice.balance;
        Q17InflateAttacker attacker = lab.attackerOf(alice);
        Q17InflateHelper helper = lab.helperOf(alice);

        vm.startPrank(alice);
        attacker.drain();
        helper.drain();
        vm.stopPrank();

        assertEq(address(lab.attackerOf(alice)).balance, 0);
        assertEq(address(lab.helperOf(alice)).balance, 0);
        assertEq(alice.balance, aliceBefore + 2 ether);
    }

    function test_NonOwnerAttackerCallReverts() public {
        vm.prank(alice);
        lab.createInstance();
        Q17InflateAttacker attacker = lab.attackerOf(alice);

        vm.deal(bob, 1 ether);
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
