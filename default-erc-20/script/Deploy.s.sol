// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        MyERC20 token = new MyERC20("MyERC20", "ME2", 100_000_000 ether);
        console.log("MyERC20 deployed at:", address(token));

        vm.stopBroadcast();
    }
}
