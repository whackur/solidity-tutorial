// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage internal store;
    address internal user = address(0xBEEF);

    event ValueChanged(address indexed by, uint256 oldValue, uint256 newValue);

    function setUp() public {
        store = new SimpleStorage();
    }

    function test_GetReturnsZeroInitially() public view {
        assertEq(store.get(), 0);
    }

    function test_SetEmitsValueChanged() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit ValueChanged(user, 0, 42);
        store.set(42);
        assertEq(store.get(), 42);
    }

    function testFuzz_SetThenGet(uint256 v) public {
        store.set(v);
        assertEq(store.get(), v);
    }
}
