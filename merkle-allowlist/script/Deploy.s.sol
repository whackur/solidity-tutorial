// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";
import {MerkleDistributor} from "../src/MerkleDistributor.sol";
import {AllowlistRestrictedToken} from "../src/AllowlistRestrictedToken.sol";

/**
 * @notice Deploys the allowlist gate and a distributor.
 *
 *         Roots are supplied by the operator, because a real tree is built
 *         off-chain from the actual member and allocation lists. Both default
 *         to zero: the allowlist then rejects registration until a root is
 *         set, which is the safe default.
 */
contract Deploy is Script {
    function run() external {
        bytes32 allowlistRoot = vm.envOr("ALLOWLIST_MERKLE_ROOT", bytes32(0));
        bytes32 distributionRoot = vm.envOr("DISTRIBUTION_MERKLE_ROOT", bytes32(0));
        uint256 distributionFunding = vm.envOr("DISTRIBUTION_FUNDING", uint256(0));
        if (distributionFunding > 0) {
            require(distributionRoot != bytes32(0), "distribution root required for funding");
        }

        vm.startBroadcast();
        MerkleAllowlist allowlist = new MerkleAllowlist(allowlistRoot, msg.sender);
        AllowlistRestrictedToken restrictedToken =
            new AllowlistRestrictedToken(allowlist, msg.sender, 1_000_000 ether);
        MerkleDistributor distributor =
            new MerkleDistributor(IERC20(address(restrictedToken)), distributionRoot);
        allowlist.setSystemAddress(msg.sender, true);
        allowlist.setSystemAddress(address(distributor), true);
        if (distributionFunding > 0) {
            require(
                restrictedToken.transfer(address(distributor), distributionFunding),
                "distributor funding failed"
            );
        }
        vm.stopBroadcast();

        console2.log("=== merkle-allowlist deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", address(restrictedToken));
        console2.log("ADDR:allowlist:", address(allowlist));
        console2.log("ADDR:restrictedToken:", address(restrictedToken));
        console2.log("ADDR:distributor:", address(distributor));
        console2.logBytes32(allowlistRoot);
        console2.logBytes32(distributionRoot);
    }
}
