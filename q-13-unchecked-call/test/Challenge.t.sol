// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {UnsafePayout, RevertOnReceive} from "../src/Setup.sol";

contract Q13UncheckedCallTest is Test {
    UnsafePayout internal escrow;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        escrow = new UnsafePayout();
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        escrow.deposit{value: 1 ether}();
        escrow.payout(payable(address(escrow.trap())));
        vm.stopPrank();
    }

    function test_AliceSolves() public {
        _solve(alice);
        assertTrue(escrow.paidOut(alice));
        assertEq(escrow.escrow(alice), 0, "escrow zeroed");
        assertEq(escrow.stranded(alice), 1 ether, "stranded equal to deposit");
        assertTrue(escrow.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(escrow.isSolved(alice));
        assertTrue(escrow.isSolved(bob));
    }

    /// @notice Paying out to a normal EOA succeeds — the call returns true,
    ///         stranded stays zero, the bug does not surface.
    function test_HonestPayoutDoesNotSolve() public {
        vm.startPrank(alice);
        escrow.deposit{value: 1 ether}();
        uint256 aliceBefore = alice.balance;
        escrow.payout(payable(alice));
        vm.stopPrank();

        assertTrue(escrow.paidOut(alice));
        assertEq(escrow.escrow(alice), 0);
        assertEq(escrow.stranded(alice), 0, "honest payout leaves no stranded ETH");
        assertEq(alice.balance, aliceBefore + 1 ether);
        assertFalse(escrow.isSolved(alice), "needs a failed call to be solved");
    }

    function test_DepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("no value"));
        escrow.deposit{value: 0}();
    }

    function test_PayoutWithoutEscrowReverts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("no escrow"));
        escrow.payout(payable(alice));
    }

    function test_TrapAlwaysReverts() public {
        RevertOnReceive trap = escrow.trap();
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(trap).call{value: 1 ether}("");
        assertFalse(ok, "trap must reject ETH");
    }
}
