// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {BoxV1} from "./BoxV1.sol";

/// @notice Beacon-pointed implementation v2: APPENDS a new storage variable
///         (`lastSetter`) after V1's layout, plus an {increment} function.
/// @dev    Appending at the end keeps existing slots intact, so every
///         BeaconProxy instance retains its `_value` across the upgrade.
///         For proxies upgraded from V1, `lastSetter` starts at address(0)
///         (the slot was never written) until {set} runs on V2.
///         Inserting or reordering variables instead would corrupt state —
///         this is the layout-compatibility rule beacons share with all
///         delegatecall-based proxies.
contract BoxV2 is BoxV1 {
    address public lastSetter;

    event ValueSet(address indexed by, uint256 newValue);

    function set(uint256 newValue) external virtual override {
        _value = newValue;
        lastSetter = msg.sender;
        emit ValueSet(msg.sender, newValue);
    }

    function increment() external {
        unchecked {
            _value += 1;
        }
        lastSetter = msg.sender;
        emit ValueSet(msg.sender, _value);
    }
}
