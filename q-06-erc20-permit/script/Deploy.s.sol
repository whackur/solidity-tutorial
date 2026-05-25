// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {PermitToken, PermitChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        PermitToken token = new PermitToken();
        PermitChallenge challenge = new PermitChallenge(token);
        vm.stopBroadcast();

        console2.log("=== q-06-erc20-permit deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", address(token));
        console2.log("ADDR:challenge:", address(challenge));
    }
}
