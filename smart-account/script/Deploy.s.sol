// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";

import {SmartAccount} from "../src/SmartAccount.sol";

contract DeployScript is Script {
    function run() public returns (SmartAccount smartAccount) {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        smartAccount = new SmartAccount();
        vm.stopBroadcast();

        console.log("SmartAccount:", address(smartAccount));
        console.log("Deployer:", deployer);
    }
}
