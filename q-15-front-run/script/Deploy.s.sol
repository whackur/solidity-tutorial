// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {FrontRunLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user challenges (PRIZE = 1 ether each).
    uint256 internal constant LAB_FUNDING = 50 ether;

    function run() external {
        vm.startBroadcast();
        FrontRunLab lab = new FrontRunLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-15-front-run deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
