// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Recipient that accepts no ETH — intentionally declares neither
///         `receive` nor `fallback`, so all value-bearing calls revert.
contract EthRejector {}
