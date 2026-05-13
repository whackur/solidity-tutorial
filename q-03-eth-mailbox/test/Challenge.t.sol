// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {EthMailbox} from "../src/Setup.sol";

contract Q03MailboxTest is Test {
    EthMailbox internal mb;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        mb = new EthMailbox();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _triggerReceive(address user, uint256 value) internal {
        vm.prank(user);
        (bool ok,) = address(mb).call{value: value}("");
        require(ok, "receive call failed");
    }

    function _triggerFallback(address user, bytes32 tag) internal {
        vm.prank(user);
        (bool ok,) = address(mb).call{value: 1 ether}(
            abi.encodeWithSignature("setFallbackTag(bytes32)", tag)
        );
        require(ok, "fallback call failed");
    }

    function _triggerReceivePayable(address user, bytes32 tag, uint256 value) internal {
        vm.prank(user);
        mb.receivePayable{value: value}(tag);
    }

    function test_AliceSolvesAllThree() public {
        _triggerReceive(alice, 1 ether);
        assertTrue(mb.hitReceive(alice), "receive hit");
        assertEq(uint8(mb.lastTrigger(alice)), uint8(EthMailbox.Trigger.Receive));

        _triggerFallback(alice, bytes32(uint256(0xCAFEBABE)));
        assertTrue(mb.hitFallback(alice), "fallback hit");
        assertEq(mb.lastTag(alice), bytes32(uint256(0xCAFEBABE)));

        _triggerReceivePayable(alice, bytes32(uint256(0x1234)), 2 ether);
        assertTrue(mb.hitReceivePayable(alice), "receivePayable hit");

        assertTrue(mb.isSolved(alice), "alice solved");
    }

    function test_TwoUsersIndependent() public {
        _triggerReceive(alice, 1 ether);
        _triggerFallback(alice, bytes32(uint256(1)));
        _triggerReceivePayable(alice, bytes32(uint256(2)), 1 ether);

        _triggerReceive(bob, 1 ether);
        // bob only hits two of three
        _triggerFallback(bob, bytes32(uint256(3)));

        assertTrue(mb.isSolved(alice), "alice solved");
        assertFalse(mb.isSolved(bob), "bob not yet solved");

        _triggerReceivePayable(bob, bytes32(uint256(4)), 1 ether);
        assertTrue(mb.isSolved(bob), "bob now solved");

        // Tags are independent.
        assertEq(mb.lastTag(alice), bytes32(uint256(2)));
        assertEq(mb.lastTag(bob), bytes32(uint256(4)));
    }

    function test_PartialProgressDoesNotSolve() public {
        _triggerReceive(alice, 1 ether);
        _triggerFallback(alice, bytes32(uint256(7)));
        assertFalse(mb.isSolved(alice), "two of three is not enough");
    }
}
