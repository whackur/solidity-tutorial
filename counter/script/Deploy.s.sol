// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {BasicCounter} from "../src/BasicCounter.sol";
import {Counter} from "../src/Counter.sol";
import {EventsAndErrors} from "../src/EventsAndErrors.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        BasicCounter basicCounter = new BasicCounter();
        Counter counter = new Counter();
        EventsAndErrors eventsAndErrors = new EventsAndErrors();
        SimpleStorage simpleStorage = new SimpleStorage();
        vm.stopBroadcast();

        console2.log("=== counter deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:basicCounter:", address(basicCounter));
        console2.log("ADDR:counter:", address(counter));
        console2.log("ADDR:eventsAndErrors:", address(eventsAndErrors));
        console2.log("ADDR:simpleStorage:", address(simpleStorage));
    }
}
