// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {ExtendedERC20} from "../src/ExtendedERC20.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        ExtendedERC20 token = new ExtendedERC20(msg.sender, 100_000_000 ether);
        vm.stopBroadcast();

        console2.log("=== erc20-extended deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", address(token));
    }
}
