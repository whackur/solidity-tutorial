// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Voucher} from "../src/Voucher.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Voucher voucher = new Voucher();
        vm.stopBroadcast();

        console2.log("ADDR:voucher:", address(voucher));
    }
}
