// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {DosLab} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        // Per-user (king, attacker) pair is deployed inside createInstance().
        // The bidding ETH comes from the user, so the lab itself needs no funding.
        DosLab lab = new DosLab();
        vm.stopBroadcast();

        console2.log("=== q-14-dos-revert deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
