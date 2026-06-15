// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q18ReadOnlyLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user vaults (SEED_DEPOSIT = 0.0005 ether each).
    uint256 internal constant LAB_FUNDING = 0.01 ether;

    function run() external {
        vm.startBroadcast();
        Q18ReadOnlyLab lab = new Q18ReadOnlyLab();
        // Lab seeding is opt-in via SEED_LABS=true. Live deploys ship the
        // contract only (no ETH out); fund the lab separately when the
        // challenge must be playable. Local anvil (build-snapshot) sets it.
        if (vm.envOr("SEED_LABS", false)) {
            (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
            require(ok, "lab funding failed");
        }
        vm.stopBroadcast();

        console2.log("=== q-18-read-only-reentrancy deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
