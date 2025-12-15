// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {CounterV2} from "../src/CounterV2.sol";
import {CounterV1} from "../src/CounterV1.sol";

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        // Address of the EXISTING Proxy (replace with actual address after deployment)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy New Implementation
        CounterV2 implementationV2 = new CounterV2();
        console.log("Implementation V2 deployed at:", address(implementationV2));

        // Upgrade
        CounterV1(proxyAddress).upgradeToAndCall(address(implementationV2), "");
        console.log("Upgraded Proxy at:", proxyAddress);

        vm.stopBroadcast();
    }
}
