// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q02EventsAndErrors} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q02EventsAndErrors instance = new Q02EventsAndErrors();
        vm.stopBroadcast();

        console2.log("=== q-02-events-errors deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:eventsAndErrors:", address(instance));
    }
}
