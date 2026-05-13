// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console} from "forge-std/Script.sol";
import {Voucher} from "../src/Voucher.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        Voucher voucher = new Voucher();
        console.log("Voucher deployed at:", address(voucher));

        vm.stopBroadcast();
    }
}
