// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q26MyForwarder, Q26MetaCounter} from "../src/Setup.sol";

/// @notice Deploys q-26-meta-tx. Lines prefixed `ADDR:<key>:` are parsed by
///         docker/entrypoint.sh and merged into addresses.json. Students need
///         both the forwarder (to relay) and the counter (the target).
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q26MyForwarder forwarder = new Q26MyForwarder();
        Q26MetaCounter counter = new Q26MetaCounter(address(forwarder));
        vm.stopBroadcast();

        console2.log("=== q-26-meta-tx deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:forwarder:", address(forwarder));
        console2.log("ADDR:counter:", address(counter));
    }
}
