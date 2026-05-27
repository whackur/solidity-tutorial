// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {OwnableVault} from "../src/OwnableVault.sol";
import {RoleManagedVault} from "../src/RoleManagedVault.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        OwnableVault ownableVault = new OwnableVault(msg.sender);
        RoleManagedVault roleManagedVault = new RoleManagedVault(msg.sender);
        vm.stopBroadcast();

        console2.log("=== access-control deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:ownableVault:", address(ownableVault));
        console2.log("ADDR:roleManagedVault:", address(roleManagedVault));
    }
}
