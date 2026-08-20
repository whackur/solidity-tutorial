// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";
import {MerkleDistributor} from "../src/MerkleDistributor.sol";
import {AllowlistRestrictedToken} from "../src/AllowlistRestrictedToken.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MerkleAllowlistToken", "MALW") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

/**
 * @notice Deploys the allowlist gate, and the distributor only when a
 *         distribution root is supplied.
 *
 *         The allowlist is ownerless and every account commits its own root
 *         after deployment. The distributor root is `immutable` and cannot be
 *         set later, so deploying without `DISTRIBUTION_MERKLE_ROOT` would
 *         leave a distributor that can never settle a claim. This script skips
 *         it instead of publishing that dead address; the token role is
 *         reported for the same reason, because only the distributor uses it.
 */
contract Deploy is Script {
    function run() external {
        bytes32 distributionRoot = vm.envOr("DISTRIBUTION_MERKLE_ROOT", bytes32(0));
        bool withDistributor = distributionRoot != bytes32(0);

        // SHARED_ERC20 points at the environment-wide default token. Fall back
        // to a local mock so the package stays independently deployable.
        address token = vm.envOr("SHARED_ERC20", address(0));

        vm.startBroadcast();
        MerkleAllowlist allowlist = new MerkleAllowlist();
        AllowlistRestrictedToken restrictedToken =
            new AllowlistRestrictedToken(allowlist, msg.sender, 1_000_000 ether);
        address distributor;
        if (withDistributor) {
            if (token == address(0)) {
                token = address(new MockToken());
            }
            distributor = address(new MerkleDistributor(IERC20(token), distributionRoot));
        }
        vm.stopBroadcast();

        console2.log("=== merkle-allowlist deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:allowlist:", address(allowlist));
        console2.log("ADDR:restrictedToken:", address(restrictedToken));
        if (withDistributor) {
            console2.log("ADDR:token:", token);
            console2.log("ADDR:distributor:", distributor);
            console2.logBytes32(distributionRoot);
        } else {
            console2.log("distributor: skipped, DISTRIBUTION_MERKLE_ROOT is unset");
        }
    }
}
