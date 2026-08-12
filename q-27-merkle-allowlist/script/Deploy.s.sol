// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q27MerkleAllowlistLab} from "../src/Setup.sol";

/// @notice The lab holds no value and takes no constructor arguments — every
///         user commits their own root and proves their own assigned leaf.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q27MerkleAllowlistLab lab = new Q27MerkleAllowlistLab();
        vm.stopBroadcast();

        console2.log("=== q-27-merkle-allowlist deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
    }
}
