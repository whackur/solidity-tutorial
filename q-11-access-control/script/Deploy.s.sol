// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q11VulnerableRegistry} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q11VulnerableRegistry registry = new Q11VulnerableRegistry();
        vm.stopBroadcast();

        console2.log("=== q-11-access-control deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:registry:", address(registry));
    }
}
