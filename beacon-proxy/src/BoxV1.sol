// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @notice Beacon-pointed implementation v1.
/// @dev    BeaconProxy delegates to this; constructors are skipped, so state
///         is set via {initialize}. Storage layout must remain compatible
///         with future versions pointed to by the same beacon.
contract BoxV1 is Initializable {
    uint256 internal _value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialValue) external initializer {
        _value = initialValue;
    }

    function value() external view virtual returns (uint256) {
        return _value;
    }

    function set(uint256 newValue) external virtual {
        _value = newValue;
    }
}
