// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";

import {SmartAccount} from "../src/SmartAccount.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        SmartAccount smartAccount = new SmartAccount();
        vm.stopBroadcast();

        console2.log("ADDR:smartAccount:", address(smartAccount));
    }
}
