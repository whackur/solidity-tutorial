// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console} from "forge-std/Script.sol";
import {SignatureVerifier} from "../src/SignatureVerifier.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        SignatureVerifier verifier = new SignatureVerifier();
        console.log("SignatureVerifier deployed at:", address(verifier));

        vm.stopBroadcast();
    }
}
