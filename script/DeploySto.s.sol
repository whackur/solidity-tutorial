// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// Single-broadcast deployer for the Base Sepolia STO classroom subset.
// All transactions are created under one vm.startBroadcast() call so Forge
// assigns sequential nonces and waits for confirmations as one batch.

import {Script, console2} from "forge-std/Script.sol";
import {SimpleWallet} from "../simple-wallet/src/SimpleWallet.sol";
import {Q05SimpleWallet} from "../q-05-simple-wallet/src/Setup.sol";
import {ThirtyOneGame} from "../thirty-one-game/src/ThirtyOneGame.sol";
import {AddressBlocklist} from "../transfer-blocklist/src/AddressBlocklist.sol";
import {BlocklistRestrictedToken} from "../transfer-blocklist/src/BlocklistRestrictedToken.sol";
import {Q20Erc20BasicLab} from "../q-20-erc20-basic/src/Setup.sol";
import {Q27MerkleAllowlistLab} from "../q-27-merkle-allowlist/src/Setup.sol";

contract DeploySto is Script {
    function run() external {
        uint256 winnerPercentage = vm.envOr("THIRTYONE_WINNER_PERCENTAGE", uint256(80));
        vm.startBroadcast();

        AddressBlocklist blocklist = new AddressBlocklist(msg.sender);
        BlocklistRestrictedToken restrictedToken =
            new BlocklistRestrictedToken(blocklist, msg.sender, 1_000_000 ether);
        address shared = address(restrictedToken);
        console2.log("PKG:transfer-blocklist");
        console2.log("ADDR:token:", shared);
        console2.log("ADDR:blocklist:", address(blocklist));
        console2.log("ADDR:restrictedToken:", shared);

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
