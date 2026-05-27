// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q05SimpleWallet, Q05MockERC20} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q05SimpleWallet wallet = new Q05SimpleWallet();
        Q05MockERC20 token = new Q05MockERC20();
        vm.stopBroadcast();

        console2.log("=== q-05-simple-wallet deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:wallet:", address(wallet));
        console2.log("ADDR:token:", address(token));
    }
}
