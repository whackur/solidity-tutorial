// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";

import {MyForwarder} from "../src/MyForwarder.sol";
import {MetaCounter} from "../src/MetaCounter.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        MyForwarder forwarder = new MyForwarder();
        MetaCounter counter = new MetaCounter(address(forwarder));
        vm.stopBroadcast();

        console2.log("ADDR:forwarder:", address(forwarder));
        console2.log("ADDR:counter:", address(counter));
    }
}
