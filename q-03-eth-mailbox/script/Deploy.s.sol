// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {EthMailbox} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        EthMailbox instance = new EthMailbox();
        vm.stopBroadcast();

        console2.log("=== q-03-eth-mailbox deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:mailbox:", address(instance));
    }
}
