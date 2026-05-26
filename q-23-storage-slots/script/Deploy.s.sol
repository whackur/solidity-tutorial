// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Vault} from "../src/Setup.sol";

/// @notice Deploys q-23-storage-slots. Lines prefixed `ADDR:<key>:` are
///         parsed by docker/entrypoint.sh and merged into addresses.json.
///         The two secrets are seeded from block context so anvil's
///         deterministic accounts cannot pre-compute them off-chain.
contract Deploy is Script {
    function run() external {
        bytes32 a = keccak256(abi.encodePacked("q23.A", block.timestamp, blockhash(block.number - 1)));
        bytes32 b = keccak256(abi.encodePacked("q23.B", block.timestamp, blockhash(block.number - 1)));

        vm.startBroadcast();
        Vault vault = new Vault(a, b);
        vm.stopBroadcast();

        console2.log("=== q-23-storage-slots deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:vault:", address(vault));
    }
}
