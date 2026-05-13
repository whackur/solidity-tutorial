// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Trimmed showcase of every revert variant the lecture covers.
/// @dev    Reference source: ../counter/src/EventsAndErrors.sol
contract EventsAndErrors {
    error InsufficientBalance(uint256 available, uint256 required);

    function failWithRequire(uint256 v) external pure {
        require(v != 0, "value must be non-zero");
    }

    function failWithAssert(bool cond) external pure {
        assert(cond);
    }

    function failWithCustomError(uint256 available, uint256 required) external pure {
        if (available < required) revert InsufficientBalance(available, required);
    }
}
