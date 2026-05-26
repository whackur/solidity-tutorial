// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {CounterV1} from "../src/CounterV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        CounterV1 implementation = new CounterV1();
        bytes memory initData = abi.encodeCall(CounterV1.initialize, (msg.sender));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        vm.stopBroadcast();

        console2.log("ADDR:implementation:", address(implementation));
        console2.log("ADDR:proxy:", address(proxy));
    }
}
