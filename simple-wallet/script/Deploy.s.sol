// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleWallet} from "../src/SimpleWallet.sol";

interface ISystemAllowlist {
    function setSystemAddress(address account, bool allowed) external;
}

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        SimpleWallet wallet = new SimpleWallet();
        bool useSharedAllowlist = vm.envOr("STO_SHARED_ALLOWLIST", false);
        address allowlist = useSharedAllowlist ? vm.envAddress("SHARED_ALLOWLIST") : address(0);
        if (allowlist != address(0)) {
            ISystemAllowlist(allowlist).setSystemAddress(address(wallet), true);
        }
        vm.stopBroadcast();

        console2.log("ADDR:wallet:", address(wallet));
        if (allowlist != address(0)) {
            console2.log("ADDR:allowlist:", allowlist);
        }
    }
}
