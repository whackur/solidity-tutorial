// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {UupsLab} from "../src/Setup.sol";

/// @notice Deploys q-25-uups-upgrade. Lines prefixed `ADDR:<key>:` are parsed
///         by docker/entrypoint.sh and merged into addresses.json. The V2
///         implementation address is exposed so students know what to pass to
///         upgradeToAndCall.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        UupsLab lab = new UupsLab();
        vm.stopBroadcast();

        console2.log("=== q-25-uups-upgrade deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
        console2.log("ADDR:v1Impl:", address(lab.v1Impl()));
        console2.log("ADDR:v2Impl:", address(lab.v2Impl()));
    }
}
