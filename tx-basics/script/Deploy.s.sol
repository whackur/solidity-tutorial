// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";

import {DelegateCaller, DelegateLogic} from "../src/DelegatecallDemo.sol";
import {EthSender} from "../src/EthSender.sol";
import {EthMailbox} from "../src/EthMailbox.sol";
import {EthSink} from "../src/EthSink.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        EthSender sender = new EthSender();
        EthMailbox mailbox = new EthMailbox();
        EthSink sink = new EthSink();
        DelegateLogic delegateLogic = new DelegateLogic();
        DelegateCaller delegateCaller = new DelegateCaller();

        vm.stopBroadcast();

        console.log("EthSender:", address(sender));
        console.log("EthMailbox:", address(mailbox));
        console.log("EthSink:", address(sink));
        console.log("DelegateLogic:", address(delegateLogic));
        console.log("DelegateCaller:", address(delegateCaller));
    }
}
