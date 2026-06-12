// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {AllowanceToken} from "../src/AllowanceToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        AllowanceToken token = new AllowanceToken("AllowanceToken", "ATK", 100_000_000 ether);
        TokenBank bank = new TokenBank(token);
        vm.stopBroadcast();

        console2.log("ADDR:token:", address(token));
        console2.log("ADDR:bank:", address(bank));
    }
}
