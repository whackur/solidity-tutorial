// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q05SimpleWallet, Q05MockERC20} from "../src/Setup.sol";

interface ISystemAllowlist {
    function setSystemAddress(address account, bool allowed) external;
}

contract Deploy is Script {
    function run() external {
        // SHARED_ERC20 points at the environment-wide default-erc-20 token
        // (set by docker/build-snapshot.sh). Fall back to a local mock so the
        // package stays independently deployable.
        address token = vm.envOr("SHARED_ERC20", address(0));

        vm.startBroadcast();
        Q05SimpleWallet wallet = new Q05SimpleWallet();
        if (token == address(0)) {
            token = address(new Q05MockERC20());
        }
        bool useSharedAllowlist = vm.envOr("STO_SHARED_ALLOWLIST", false);
        address allowlist = useSharedAllowlist ? vm.envAddress("SHARED_ALLOWLIST") : address(0);
        if (allowlist != address(0)) {
            ISystemAllowlist(allowlist).setSystemAddress(address(wallet), true);
        }
        vm.stopBroadcast();

        console2.log("=== q-05-simple-wallet deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:wallet:", address(wallet));
        console2.log("ADDR:token:", token);
        if (allowlist != address(0)) {
            console2.log("ADDR:allowlist:", allowlist);
        }
    }
}
