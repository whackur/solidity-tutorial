// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {SimpleWallet} from "../src/SimpleWallet.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        SimpleWallet wallet = new SimpleWallet();
        console.log("SimpleWallet deployed at:", address(wallet));

        vm.stopBroadcast();
    }
}
