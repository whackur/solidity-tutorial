// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q22SpotPriceBasicLab} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q22SpotPriceBasicLab lab = new Q22SpotPriceBasicLab();
        vm.stopBroadcast();

        console2.log("=== q-22-spot-price-basic deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
