// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console} from "forge-std/Script.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {BoxV1} from "../src/BoxV1.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BoxV1 impl = new BoxV1();
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(impl), deployer);
        BeaconProxy proxy = new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.initialize, (42)));

        vm.stopBroadcast();

        console.log("BoxV1 implementation:", address(impl));
        console.log("UpgradeableBeacon:", address(beacon));
        console.log("BeaconProxy:", address(proxy));
    }
}
