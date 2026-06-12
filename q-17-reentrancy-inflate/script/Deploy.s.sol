// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q17InflateLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user vaults (SEED = 0.001 ether each).
    uint256 internal constant LAB_FUNDING = 0.05 ether;

    function run() external {
        vm.startBroadcast();
        Q17InflateLab lab = new Q17InflateLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-17-reentrancy-inflate deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
