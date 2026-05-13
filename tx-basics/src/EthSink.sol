// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Minimal recipient — a `receive` with no state mutation. Falls
///         within the 2300-gas stipend so `transfer` and `send` succeed.
contract EthSink {
    receive() external payable {}
}
