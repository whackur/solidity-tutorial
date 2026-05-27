// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q20Erc20BasicLab} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q20Erc20BasicLab lab = new Q20Erc20BasicLab();
        vm.stopBroadcast();

        console2.log("=== q-20-erc20-basic deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
        console2.log("ADDR:faucet:", address(lab.faucet()));
        console2.log("ADDR:vault:", address(lab.vault()));
    }
}
