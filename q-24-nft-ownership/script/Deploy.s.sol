// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {NftLab} from "../src/Setup.sol";

/// @notice Deploys q-24-nft-ownership. Lines prefixed `ADDR:<key>:` are parsed
///         by docker/entrypoint.sh and merged into addresses.json.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        NftLab lab = new NftLab();
        vm.stopBroadcast();

        console2.log("=== q-24-nft-ownership deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
        console2.log("ADDR:nft:", address(lab.nft()));
    }
}
