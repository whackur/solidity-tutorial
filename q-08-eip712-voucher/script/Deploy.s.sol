// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {VoucherChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        // VoucherChallenge's constructor internally deploys VoucherToken, so
        // we capture the token address from the deployed challenge.
        VoucherChallenge challenge = new VoucherChallenge();
        vm.stopBroadcast();

        console2.log("=== q-08-eip712-voucher deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:challenge:", address(challenge));
        console2.log("ADDR:token:", address(challenge.token()));
    }
}
