// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title BasicCounter — the simplest possible state-changing contract
/// @notice Three state-changing transactions over a single storage slot:
///         add (+1), sub (-1), reset (to 0). Pure tx-flow practice — no events, no errors.
contract BasicCounter {
    uint256 public count;

    function add() external {
        count += 1;
    }

    function sub() external {
        count -= 1;
    }

    function reset() external {
        count = 0;
    }
}
