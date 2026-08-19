// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// Single-broadcast deployer for the Base Sepolia STO classroom subset.
// All transactions are created under one vm.startBroadcast() call so Forge
// assigns sequential nonces and waits for confirmations as one batch.

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MyERC20} from "../default-erc-20/src/MyERC20.sol";
import {SimpleWallet} from "../simple-wallet/src/SimpleWallet.sol";
import {Q05SimpleWallet} from "../q-05-simple-wallet/src/Setup.sol";
import {ThirtyOneGame} from "../thirty-one-game/src/ThirtyOneGame.sol";
import {MerkleAllowlist} from "../merkle-allowlist/src/MerkleAllowlist.sol";
import {AllowlistRestrictedToken} from "../merkle-allowlist/src/AllowlistRestrictedToken.sol";
import {MerkleDistributor} from "../merkle-allowlist/src/MerkleDistributor.sol";
import {Q20Erc20BasicLab} from "../q-20-erc20-basic/src/Setup.sol";
import {Q27MerkleAllowlistLab} from "../q-27-merkle-allowlist/src/Setup.sol";

contract DeploySto is Script {
    function run() external {
        uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));
        bytes32 allowlistRoot = vm.envOr("ALLOWLIST_MERKLE_ROOT", bytes32(0));
        bytes32 distributionRoot = vm.envOr("DISTRIBUTION_MERKLE_ROOT", bytes32(0));

        vm.startBroadcast();

        MyERC20 sharedToken = new MyERC20("MyERC20", "ME2", 100_000_000 ether);
        address shared = address(sharedToken);
        console2.log("PKG:default-erc-20");
        console2.log("ADDR:token:", shared);

        SimpleWallet wallet = new SimpleWallet();
        console2.log("PKG:simple-wallet");
        console2.log("ADDR:wallet:", address(wallet));

        Q05SimpleWallet q05Wallet = new Q05SimpleWallet();
        console2.log("PKG:q-05-simple-wallet");
        console2.log("ADDR:wallet:", address(q05Wallet));
        console2.log("ADDR:token:", shared);

        ThirtyOneGame game = new ThirtyOneGame(shared, winnerPercentage);
        console2.log("PKG:thirty-one-game");
        console2.log("ADDR:token:", shared);
        console2.log("ADDR:game:", address(game));

        MerkleAllowlist allowlist = new MerkleAllowlist(allowlistRoot, msg.sender);
        AllowlistRestrictedToken restrictedToken =
            new AllowlistRestrictedToken(allowlist, msg.sender, 1_000_000 ether);
        MerkleDistributor distributor = new MerkleDistributor(IERC20(shared), distributionRoot);
        console2.log("PKG:merkle-allowlist");
        console2.log("ADDR:token:", shared);
        console2.log("ADDR:allowlist:", address(allowlist));
        console2.log("ADDR:restrictedToken:", address(restrictedToken));
        console2.log("ADDR:distributor:", address(distributor));

        Q20Erc20BasicLab q20Lab = new Q20Erc20BasicLab();
        console2.log("PKG:q-20-erc20-basic");
        console2.log("ADDR:lab:", address(q20Lab));
        console2.log("ADDR:faucet:", address(q20Lab.faucet()));
        console2.log("ADDR:vault:", address(q20Lab.vault()));

        Q27MerkleAllowlistLab q27Lab = new Q27MerkleAllowlistLab();
        console2.log("PKG:q-27-merkle-allowlist");
        console2.log("ADDR:lab:", address(q27Lab));

        vm.stopBroadcast();
    }
}
