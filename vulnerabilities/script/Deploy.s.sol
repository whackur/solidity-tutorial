// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {VulnerableVault} from "../src/reentrancy/VulnerableVault.sol";
import {SafeVault} from "../src/reentrancy/SafeVault.sol";
import {MockPool} from "../src/oracle-manipulation/MockPool.sol";
import {VulnerableLending} from "../src/oracle-manipulation/VulnerableLending.sol";
import {SafeLending} from "../src/oracle-manipulation/SafeLending.sol";
import {VulnerableSigClaim} from "../src/signature-replay/VulnerableSigClaim.sol";
import {SafeSigClaim} from "../src/signature-replay/SafeSigClaim.sol";
import {VulnerableWallet} from "../src/tx-origin/VulnerableWallet.sol";
import {SafeWallet} from "../src/tx-origin/SafeWallet.sol";

/// @notice Deploys the teaching pairs (vulnerable + safe) for each category.
///         Attack helpers (ReentrancyAttacker, Phisher) are exercised in tests,
///         not deployed here.
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // reentrancy
        VulnerableVault vulnerableVault = new VulnerableVault();
        SafeVault safeVault = new SafeVault();

        // oracle manipulation
        MockPool mockPool = new MockPool(1000 ether, 1000 ether);
        VulnerableLending vulnerableLending = new VulnerableLending(address(mockPool));
        SafeLending safeLending = new SafeLending(msg.sender, 1 ether);

        // signature replay
        VulnerableSigClaim vulnerableSigClaim = new VulnerableSigClaim(msg.sender);
        SafeSigClaim safeSigClaim = new SafeSigClaim(msg.sender);

        // tx.origin
        VulnerableWallet vulnerableWallet = new VulnerableWallet();
        SafeWallet safeWallet = new SafeWallet();

        vm.stopBroadcast();

        console2.log("=== vulnerabilities deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:vulnerableVault:", address(vulnerableVault));
        console2.log("ADDR:safeVault:", address(safeVault));
        console2.log("ADDR:mockPool:", address(mockPool));
        console2.log("ADDR:vulnerableLending:", address(vulnerableLending));
        console2.log("ADDR:safeLending:", address(safeLending));
        console2.log("ADDR:vulnerableSigClaim:", address(vulnerableSigClaim));
        console2.log("ADDR:safeSigClaim:", address(safeSigClaim));
        console2.log("ADDR:vulnerableWallet:", address(vulnerableWallet));
        console2.log("ADDR:safeWallet:", address(safeWallet));
    }
}
