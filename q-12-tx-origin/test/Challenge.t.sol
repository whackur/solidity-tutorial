// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {TxOriginLab, TxOriginVault, Phisher} from "../src/Setup.sol";

contract Q12TxOriginTest is Test {
    TxOriginLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new TxOriginLab();
        vm.deal(address(lab), 100 ether);
    }

    function _solve(address user) internal {
        // Use the (sender, origin) prank form so tx.origin == user, matching
        // a real wallet-initiated transaction.
        vm.prank(user, user);
        lab.createInstance();
        Phisher phisher = lab.phisherOf(user);

        // User clicks the "free airdrop" button — tx originates from them,
        // so tx.origin == vault.owner and the vault drain succeeds.
        vm.prank(user, user);
        phisher.claimFreeAirdrop();
    }

    function test_AliceSolves() public {
        _solve(alice);
        TxOriginVault vault = lab.vaultOf(alice);
        assertEq(address(vault).balance, 0, "vault drained");
        assertEq(alice.balance, 5 ether, "drained funds returned to alice");
        assertTrue(lab.phisherOf(alice).airdropClaimed());
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        assertTrue(lab.vaultOf(alice) != lab.vaultOf(bob));
        assertTrue(lab.phisherOf(alice) != lab.phisherOf(bob));
    }

    /// @notice A third party calling the phisher does NOT drain — tx.origin
    ///         would be them, not the owner. This is the bug acting as
    ///         (incidental) protection in this direction.
    function test_OutsidePhisherCallFails() public {
        vm.prank(alice, alice);
        lab.createInstance();
        Phisher phisher = lab.phisherOf(alice);

        vm.prank(bob, bob);
        vm.expectRevert(bytes("not owner"));
        phisher.claimFreeAirdrop();

        assertFalse(lab.isSolved(alice));
    }

    function test_DirectVaultCallByOwnerStillWorks() public {
        vm.prank(alice, alice);
        lab.createInstance();
        TxOriginVault vault = lab.vaultOf(alice);
        // Alice can of course also withdraw directly — tx.origin == msg.sender == owner.
        vm.prank(alice, alice);
        vault.transferTo(payable(alice), 1 ether);
        assertEq(address(vault).balance, 4 ether);
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice, alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
