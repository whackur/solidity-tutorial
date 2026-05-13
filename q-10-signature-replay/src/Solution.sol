// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IVulnerableSigClaim} from "./Setup.sol";

contract Solution {
    /// @notice Replay the same (to, amount, signature) tuple `times` times.
    function replay(
        IVulnerableSigClaim claim,
        address payable to,
        uint256 amount,
        bytes calldata signature,
        uint256 times
    ) external {
        // TODO: loop `times` times and call claim.claim(to, amount, signature).
        //       Hint: for (uint256 i = 0; i < times; ++i) claim.claim(to, amount, signature);
        claim; to; amount; signature; times;
        revert("Solution.replay: not implemented");
    }

    receive() external payable {}
}
