// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";

import {DelegateCaller, DelegateLogic} from "../src/DelegatecallDemo.sol";
import {EthSender} from "../src/EthSender.sol";
import {EthMailbox} from "../src/EthMailbox.sol";
import {EthSink} from "../src/EthSink.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        EthSender sender = new EthSender();
        EthMailbox mailbox = new EthMailbox();
        EthSink sink = new EthSink();
        DelegateLogic delegateLogic = new DelegateLogic();
        DelegateCaller delegateCaller = new DelegateCaller();
        vm.stopBroadcast();

        console2.log("ADDR:ethSender:", address(sender));
        console2.log("ADDR:ethMailbox:", address(mailbox));
        console2.log("ADDR:ethSink:", address(sink));
        console2.log("ADDR:delegateLogic:", address(delegateLogic));
        console2.log("ADDR:delegateCaller:", address(delegateCaller));
    }
}
