// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {EthSignChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        EthSignChallenge challenge = new EthSignChallenge();
        vm.stopBroadcast();

        console2.log("=== q-07-eth-sign deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:challenge:", address(challenge));
    }
}
