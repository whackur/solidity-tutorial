// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {AddressBlocklist} from "../src/AddressBlocklist.sol";
import {BlocklistRestrictedToken} from "../src/BlocklistRestrictedToken.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        AddressBlocklist blocklist = new AddressBlocklist(msg.sender);
        BlocklistRestrictedToken restrictedToken =
            new BlocklistRestrictedToken(blocklist, msg.sender, 1_000_000 ether);
        vm.stopBroadcast();

        console2.log("ADDR:token:", address(restrictedToken));
        console2.log("ADDR:blocklist:", address(blocklist));
        console2.log("ADDR:restrictedToken:", address(restrictedToken));
    }
}
