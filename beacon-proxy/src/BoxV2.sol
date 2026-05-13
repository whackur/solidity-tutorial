// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {BoxV1} from "./BoxV1.sol";

/// @notice Beacon-pointed implementation v2: appends {increment} without
///         changing the underlying storage layout, so existing BeaconProxy
///         instances retain their state across the upgrade.
contract BoxV2 is BoxV1 {
    function increment() external {
        unchecked {
            _value += 1;
        }
    }
}
