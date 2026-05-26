// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ThirtyOneGame} from "../src/ThirtyOneGame.sol";

contract MockToken is ERC20 {
    constructor() ERC20("ThirtyOneTestToken", "T31") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract Deploy is Script {
    function run() external {
        uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));

        vm.startBroadcast();
        MockToken token = new MockToken();
        ThirtyOneGame game = new ThirtyOneGame(address(token), winnerPercentage);
        vm.stopBroadcast();

        console2.log("ADDR:token:", address(token));
        console2.log("ADDR:game:", address(game));
    }
}
