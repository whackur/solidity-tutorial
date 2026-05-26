// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Implementation} from "../src/Implementation.sol";
import {Factory} from "../src/Factory.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Implementation implementation = new Implementation();
        Factory factory = new Factory(address(implementation));
        vm.stopBroadcast();

        console2.log("ADDR:implementation:", address(implementation));
        console2.log("ADDR:factory:", address(factory));
    }
}
