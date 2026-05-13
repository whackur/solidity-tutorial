// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title SimpleStorage — single storage slot read/write + event notification
/// @notice The most basic contract responsibility: store a value and notify the outside on change
contract SimpleStorage {
    uint256 private _value;

    /// @dev Only `by` is indexed: lets off-chain consumers filter by *who changed the value*.
    ///      The values (oldValue/newValue) are non-indexed and end up in the ABI-encoded data.
    event ValueChanged(address indexed by, uint256 oldValue, uint256 newValue);

    function set(uint256 newValue) external {
        uint256 old = _value;
        _value = newValue;
        emit ValueChanged(msg.sender, old, newValue);
    }

    function get() external view returns (uint256) {
        return _value;
    }
}
