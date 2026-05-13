// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";

/// @notice Beacon proxy pattern: many proxies, one beacon, one upgrade switch.
contract BeaconProxyTest is Test {
    address internal owner = address(this);
    address internal stranger = makeAddr("stranger");

    UpgradeableBeacon internal beacon;
    BoxV1 internal boxA;
    BoxV1 internal boxB;

    function setUp() public {
        BoxV1 implV1 = new BoxV1();
        beacon = new UpgradeableBeacon(address(implV1), owner);

        boxA = BoxV1(address(new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.initialize, (10)))));
        boxB = BoxV1(address(new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.initialize, (20)))));
    }

    function test_proxiesShareImplementationViaBeacon() public view {
        assertEq(boxA.value(), 10);
        assertEq(boxB.value(), 20);
        assertTrue(beacon.implementation() != address(0));
    }

    function test_setUpdatesIndividualProxyStorage() public {
        boxA.set(100);
        boxB.set(200);
        assertEq(boxA.value(), 100);
        assertEq(boxB.value(), 200);
    }

    function test_upgradePropagatesToAllProxies() public {
        BoxV2 implV2 = new BoxV2();
        beacon.upgradeTo(address(implV2));

        BoxV2 upgradedA = BoxV2(address(boxA));
        BoxV2 upgradedB = BoxV2(address(boxB));

        upgradedA.increment();
        upgradedA.increment();
        upgradedB.increment();

        assertEq(upgradedA.value(), 12);
        assertEq(upgradedB.value(), 21);
    }

    function test_upgradeOnlyByBeaconOwner() public {
        BoxV2 implV2 = new BoxV2();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        beacon.upgradeTo(address(implV2));
    }

    function test_upgradeRejectsNonContractImplementation() public {
        address eoa = makeAddr("eoa");
        vm.expectRevert(abi.encodeWithSelector(UpgradeableBeacon.BeaconInvalidImplementation.selector, eoa));
        beacon.upgradeTo(eoa);
    }
}
