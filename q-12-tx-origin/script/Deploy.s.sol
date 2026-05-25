// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {TxOriginLab} from "../src/Setup.sol";

contract Deploy is Script {
    /// Funds the lab so it can seed many per-user vaults (SEED = 5 ether each).
    uint256 internal constant LAB_FUNDING = 100 ether;

    function run() external {
        vm.startBroadcast();
        TxOriginLab lab = new TxOriginLab();
        (bool ok,) = address(lab).call{value: LAB_FUNDING}("");
        require(ok, "lab funding failed");
        vm.stopBroadcast();

        console2.log("=== q-12-tx-origin deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
