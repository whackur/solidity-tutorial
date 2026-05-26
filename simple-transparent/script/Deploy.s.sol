// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Box} from "../src/Box.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Box implementation = new Box();
        bytes memory initData = abi.encodeCall(Box.initialize, (42));
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), msg.sender, initData);
        vm.stopBroadcast();

        console2.log("ADDR:implementation:", address(implementation));
        console2.log("ADDR:proxy:", address(proxy));
    }
}
