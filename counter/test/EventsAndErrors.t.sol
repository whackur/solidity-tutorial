// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {EventsAndErrors} from "../src/EventsAndErrors.sol";

contract EventsAndErrorsTest is Test {
    EventsAndErrors internal demo;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    event NoIndexedEvent(uint256 a, uint256 b);
    event OneIndexedEvent(address indexed from, uint256 amount);
    event TwoIndexedEvent(address indexed from, address indexed to, uint256 amount);
    event ThreeIndexedEvent(
        address indexed from, address indexed to, uint256 indexed id, uint256 amount
    );

    function setUp() public {
        demo = new EventsAndErrors();
    }

    function test_TwoIndexedTopicMatchesSignatureHash() public view {
        bytes32 expected = keccak256("TwoIndexedEvent(address,address,uint256)");
        assertEq(demo.twoIndexedTopic0(), expected);
    }

    function test_ErrorStringSelectorIs0x08c379a0() public view {
        assertEq(demo.errorStringSelector(), bytes4(0x08c379a0));
    }

    function test_PanicSelectorIs0x4e487b71() public view {
        assertEq(demo.panicSelector(), bytes4(0x4e487b71));
    }

    function test_EmitAllProducesEachEvent() public {
        // Only TwoIndexedEvent is asserted explicitly — Foundry tolerates other events emitted in the same tx.
        vm.expectEmit(true, true, false, true);
        emit TwoIndexedEvent(alice, bob, 100);
        demo.emitAll(alice, bob, 7, 100, 1);
    }

    function test_RequireRevertsWithErrorString() public {
        vm.expectRevert(bytes("value must be non-zero"));
        demo.failWithRequire(0);
    }

    function test_RevertStringSameAsRequire() public {
        vm.expectRevert(bytes("value must be non-zero"));
        demo.failWithRevertString(0);
    }

    function test_CustomErrorCarriesArguments() public {
        vm.expectRevert(
            abi.encodeWithSelector(EventsAndErrors.InsufficientBalance.selector, 1, 5)
        );
        demo.failWithCustomError(1, 5);
    }

    function test_AssertProducesPanicCode1() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x01));
        demo.failWithAssert(false);
    }

    function test_OverflowProducesPanicCode17() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        demo.triggerAutoPanic(17);
    }

    function test_DivByZeroProducesPanicCode18() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x12));
        demo.triggerAutoPanic(18);
    }

    function test_ArrayOOBProducesPanicCode50() public {
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x32));
        demo.triggerAutoPanic(50);
    }
}
