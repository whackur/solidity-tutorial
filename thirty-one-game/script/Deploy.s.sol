// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script, console} from "forge-std/Script.sol";
import {ThirtyOneGame} from "../src/ThirtyOneGame.sol";

contract DeployScript is Script {
    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        address tokenAddress = vm.envAddress("THIRTYONE_TOKEN_ADDRESS");
        uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));

        vm.startBroadcast(deployerPrivateKey);

        ThirtyOneGame game = new ThirtyOneGame(tokenAddress, winnerPercentage);
        console.log("ThirtyOneGame deployed at:", address(game));

        vm.stopBroadcast();
    }
}
