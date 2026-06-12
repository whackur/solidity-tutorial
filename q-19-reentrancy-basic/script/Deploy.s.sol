// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q19ReentrancyBasicLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user instances
    /// (SEED 0.005 ether + BAIT 0.00005 ether per user).
    uint256 internal constant LAB_FUNDING = 0.1 ether;

    function run() external {
        vm.startBroadcast();
        Q19ReentrancyBasicLab lab = new Q19ReentrancyBasicLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-19-reentrancy-basic deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
