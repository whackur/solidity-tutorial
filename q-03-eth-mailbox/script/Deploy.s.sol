// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q03EthMailbox} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q03EthMailbox instance = new Q03EthMailbox();
        vm.stopBroadcast();

        console2.log("=== q-03-eth-mailbox deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:mailbox:", address(instance));
    }
}
