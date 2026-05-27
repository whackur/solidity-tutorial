// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q01Counter} from "../src/Setup.sol";

/// @notice Multi-chain deploy for q-01-counter. Lines prefixed `ADDR:<key>:`
///         are parsed by docker/entrypoint.sh and merged into addresses.json.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q01Counter counter = new Q01Counter();
        vm.stopBroadcast();

        console2.log("=== q-01-counter deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:counter:", address(counter));
    }
}
