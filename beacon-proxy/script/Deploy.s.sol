// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BoxV1} from "../src/BoxV1.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        BoxV1 impl = new BoxV1();
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(impl), msg.sender);
        BeaconProxy proxy = new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.initialize, (42)));
        vm.stopBroadcast();

        console2.log("ADDR:implementation:", address(impl));
        console2.log("ADDR:beacon:", address(beacon));
        console2.log("ADDR:proxy:", address(proxy));
    }
}
