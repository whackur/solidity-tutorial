// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        MyERC721 nft = new MyERC721("MyERC721", "ME7");
        console.log("MyERC721 deployed at:", address(nft));

        vm.stopBroadcast();
    }
}
