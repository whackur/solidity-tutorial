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
        // SHARED_ERC20 points at the environment-wide default-erc-20 token
        // (set by docker/build-snapshot.sh). Fall back to a local mock so the
        // package stays independently deployable.
        address token = vm.envOr("SHARED_ERC20", address(0));

        vm.startBroadcast();
        if (token == address(0)) {
            token = address(new MockToken());
        }
        ThirtyOneGame game = new ThirtyOneGame(token, winnerPercentage);
        vm.stopBroadcast();

        console2.log("ADDR:token:", token);
        console2.log("ADDR:game:", address(game));
    }
}
