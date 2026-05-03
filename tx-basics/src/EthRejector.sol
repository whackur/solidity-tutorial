// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Recipient that accepts no ETH — declares neither `receive` nor
///         `fallback`. All value-bearing calls revert.
contract EthRejector {
// Intentionally empty.
}
