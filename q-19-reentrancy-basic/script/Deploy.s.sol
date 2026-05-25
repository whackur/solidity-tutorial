// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {ReentrancyBasicLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user instances
    /// (SEED 5 ether + BAIT 0.05 ether per user).
    uint256 internal constant LAB_FUNDING = 100 ether;

    function run() external {
        vm.startBroadcast();
        ReentrancyBasicLab lab = new ReentrancyBasicLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-19-reentrancy-basic deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
