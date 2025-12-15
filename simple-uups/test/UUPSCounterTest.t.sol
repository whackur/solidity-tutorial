// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CounterV1} from "../src/CounterV1.sol";
import {CounterV2} from "../src/CounterV2.sol";

contract UUPSCounterTest is Test {
    CounterV1 public implementationV1;
    CounterV2 public implementationV2;
    CounterV1 public proxy;
    address public owner;

    function setUp() public {
        owner = address(this);

        // 1. Deploy Implementation V1
        implementationV1 = new CounterV1();

        // 2. Deploy Proxy pointing to V1, initialize it
        bytes memory initData = abi.encodeCall(CounterV1.initialize, (owner));
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementationV1), initData);

        // 3. Wrap proxy in V1 interface
        proxy = CounterV1(address(proxyContract));
    }

    function test_Increment() public {
        assertEq(proxy.count(), 0);
        proxy.increment();
        assertEq(proxy.count(), 1);
    }

    function test_Upgrade() public {
        // Increment first
        proxy.increment();
        uint256 valueBefore = proxy.count();
        assertEq(valueBefore, 1);

        // Deploy V2
        implementationV2 = new CounterV2();

        // Upgrade
        proxy.upgradeToAndCall(address(implementationV2), "");

        // Wrap as V2
        CounterV2 proxyV2 = CounterV2(address(proxy));

        // Check state preserved
        assertEq(proxyV2.count(), 1);

        // Check V2 functionality
        proxyV2.decrement();
        assertEq(proxyV2.count(), 0);

        // Check access control on upgrade
        // Try to upgrade from non-owner (should fail)
        vm.prank(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyV2.upgradeToAndCall(address(implementationV1), "");
    }
}
