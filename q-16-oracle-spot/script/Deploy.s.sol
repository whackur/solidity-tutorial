// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q16OracleLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user instances
    /// (POOL_ETH_SEED 0.01 ether + LENDER_SEED 0.05 ether per user).
    uint256 internal constant LAB_FUNDING = 1 ether;

    function run() external {
        vm.startBroadcast();
        Q16OracleLab lab = new Q16OracleLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-16-oracle-spot deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
