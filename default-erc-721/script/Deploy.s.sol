// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        MyERC721 nft = new MyERC721("MyERC721", "ME7");
        vm.stopBroadcast();

        console2.log("ADDR:nft:", address(nft));
    }
}
