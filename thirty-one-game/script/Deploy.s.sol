// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ThirtyOneGame} from "../src/ThirtyOneGame.sol";

interface ISystemAllowlist {
    function setSystemAddress(address account, bool allowed) external;
}

contract MockToken is ERC20 {
    constructor() ERC20("ThirtyOneTestToken", "T31") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract Deploy is Script {
    function run() external {
        uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));
        // SHARED_ERC20 points at the environment's classroom token. Fall back
        // to a local mock so the package stays independently deployable.
        address token = vm.envOr("SHARED_ERC20", address(0));

        vm.startBroadcast();
        if (token == address(0)) {
            token = address(new MockToken());
        }
        ThirtyOneGame game = new ThirtyOneGame(token, winnerPercentage);
        bool useSharedAllowlist = vm.envOr("STO_SHARED_ALLOWLIST", false);
        address allowlist = useSharedAllowlist ? vm.envAddress("SHARED_ALLOWLIST") : address(0);
        if (allowlist != address(0)) {
            ISystemAllowlist(allowlist).setSystemAddress(address(game), true);
        }
        vm.stopBroadcast();

        console2.log("ADDR:token:", token);
        console2.log("ADDR:game:", address(game));
        if (allowlist != address(0)) {
            console2.log("ADDR:allowlist:", allowlist);
        }
    }
}
