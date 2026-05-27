// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {Q21EcrecoverBasicLab} from "../src/Setup.sol";

/// @notice Deploy with three deterministic candidates. Two are signed by
///         impostor keys derived from `forge std` `makeAddrAndKey`-style
///         seeds; one is signed by the trusted signer. The correct index
///         is intentionally hidden — the student must run `ecrecover`
///         off-chain on each candidate to find it.
contract Deploy is Script {
    function run() external {
        // Read three private keys from the environment so the deployer can
        // rotate keys without recompiling the script. For a quick local
        // demo, defaults are well-known Anvil keys.
        uint256 trustedPk =
            vm.envOr("TRUSTED_SIGNER_PK", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        uint256 impostorAPk =
            vm.envOr("IMPOSTOR_A_PK", uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d));
        uint256 impostorBPk =
            vm.envOr("IMPOSTOR_B_PK", uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a));

        address trustedSigner = vm.addr(trustedPk);

        Q21EcrecoverBasicLab.Candidate[] memory cands = new Q21EcrecoverBasicLab.Candidate[](3);
        cands[0] = _sign(impostorAPk, keccak256("hello from imposter A"));
        cands[1] = _sign(trustedPk, keccak256("trusted signer authorized this message"));
        cands[2] = _sign(impostorBPk, keccak256("hello from imposter B"));

        vm.startBroadcast();
        Q21EcrecoverBasicLab lab = new Q21EcrecoverBasicLab(trustedSigner, cands);
        vm.stopBroadcast();

        console2.log("=== q-21-ecrecover-basic deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:lab:", address(lab));
        console2.log("trustedSigner:", trustedSigner);
    }

    function _sign(uint256 pk, bytes32 hash) internal pure returns (Q21EcrecoverBasicLab.Candidate memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return Q21EcrecoverBasicLab.Candidate({messageHash: hash, v: v, r: r, s: s});
    }
}
