// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q07EthSignChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q07EthSignChallenge challenge = new Q07EthSignChallenge();
        vm.stopBroadcast();

        console2.log("=== q-07-eth-sign deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:challenge:", address(challenge));
    }
}
