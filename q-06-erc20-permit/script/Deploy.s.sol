// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q06PermitToken, Q06PermitChallenge} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Q06PermitToken token = new Q06PermitToken();
        Q06PermitChallenge challenge = new Q06PermitChallenge(token);
        vm.stopBroadcast();

        console2.log("=== q-06-erc20-permit deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", address(token));
        console2.log("ADDR:challenge:", address(challenge));
    }
}
