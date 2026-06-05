// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {RoleBasedERC20} from "../src/RoleBasedERC20.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        RoleBasedERC20 token = new RoleBasedERC20(msg.sender);
        vm.stopBroadcast();

        console2.log("=== erc20-roles deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", address(token));
    }
}
