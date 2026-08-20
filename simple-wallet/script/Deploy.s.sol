// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleWallet} from "../src/SimpleWallet.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        SimpleWallet wallet = new SimpleWallet();
        vm.stopBroadcast();

        console2.log("ADDR:wallet:", address(wallet));
    }
}
