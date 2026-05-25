// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {DelegatecallLab} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        // Lab only — per-user (caller, logic) pair is deployed inside
        // createInstance() at runtime, so no funding is required up-front.
        DelegatecallLab lab = new DelegatecallLab();
        vm.stopBroadcast();

        console2.log("=== q-04-delegatecall deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
