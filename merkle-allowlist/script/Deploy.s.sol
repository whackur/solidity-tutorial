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
 * @notice Deploys the allowlist gate and a distributor.
 *
 *         The allowlist is ownerless and each learner commits their own root
 *         after deployment. The distributor root is still supplied at deploy
 *         time because it is a fixed pull-claim allocation.
 */
contract Deploy is Script {
    function run() external {
        bytes32 distributionRoot = vm.envOr("DISTRIBUTION_MERKLE_ROOT", bytes32(0));

        // SHARED_ERC20 points at the environment-wide default token. Fall back
        // to a local mock so the package stays independently deployable.
        address token = vm.envOr("SHARED_ERC20", address(0));

        vm.startBroadcast();
        if (token == address(0)) {
            token = address(new MockToken());
        }
        MerkleAllowlist allowlist = new MerkleAllowlist();
        AllowlistRestrictedToken restrictedToken =
            new AllowlistRestrictedToken(allowlist, msg.sender, 1_000_000 ether);
        MerkleDistributor distributor = new MerkleDistributor(IERC20(token), distributionRoot);
        vm.stopBroadcast();

        console2.log("=== merkle-allowlist deployment ===");
        console2.log("chainId:", block.chainid);
        console2.log("ADDR:token:", token);
        console2.log("ADDR:allowlist:", address(allowlist));
        console2.log("ADDR:restrictedToken:", address(restrictedToken));
        console2.log("ADDR:distributor:", address(distributor));
        console2.logBytes32(distributionRoot);
    }
}
