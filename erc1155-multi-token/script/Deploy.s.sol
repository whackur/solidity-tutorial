// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {GameItems} from "../src/GameItems.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        GameItems gameItems = new GameItems(msg.sender);
        vm.stopBroadcast();

        console2.log("=== erc1155-multi-token deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:gameItems:", address(gameItems));
    }
}
