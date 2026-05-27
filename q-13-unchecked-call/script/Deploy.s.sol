// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q13UnsafePayout} from "../src/Setup.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        // Q13UnsafePayout's constructor internally deploys its Q13RevertOnReceive
        // trap, so we only need to surface the payout contract address.
        Q13UnsafePayout payout = new Q13UnsafePayout();
        vm.stopBroadcast();

        console2.log("=== q-13-unchecked-call deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:payout:", address(payout));
        console2.log("ADDR:trap:", address(payout.trap()));
    }
}
