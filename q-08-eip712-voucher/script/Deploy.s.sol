// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q08VoucherChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        // Q08VoucherChallenge's constructor internally deploys Q08VoucherToken, so
        // we capture the token address from the deployed challenge.
        Q08VoucherChallenge challenge = new Q08VoucherChallenge();
        vm.stopBroadcast();

        console2.log("=== q-08-eip712-voucher deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:challenge:", address(challenge));
        console2.log("ADDR:token:", address(challenge.token()));
    }
}
