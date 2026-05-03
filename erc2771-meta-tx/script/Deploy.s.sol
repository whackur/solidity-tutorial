// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";

import {MyForwarder} from "../src/MyForwarder.sol";
import {MetaCounter} from "../src/MetaCounter.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        MyForwarder forwarder = new MyForwarder();
        MetaCounter counter = new MetaCounter(address(forwarder));

        vm.stopBroadcast();

        console.log("MyForwarder:", address(forwarder));
        console.log("MetaCounter:", address(counter));
    }
}
