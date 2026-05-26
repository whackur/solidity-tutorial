// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        MyERC20 token = new MyERC20("MyERC20", "ME2", 100_000_000 ether);
        vm.stopBroadcast();

        console2.log("ADDR:token:", address(token));
    }
}
