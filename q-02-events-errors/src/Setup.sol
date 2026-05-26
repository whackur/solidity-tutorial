// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Multi-tenant revert classifier. Every user must observe three
///         distinct revert flavours and submit their 4-byte selectors back.
///         A single instance is shared across users; progress is keyed by
///         msg.sender so users do not interfere.
contract EventsAndErrors is SolvableBase {
    error InsufficientBalance(uint256 available, uint256 required);
    error WrongSelector(bytes4 submitted, bytes4 expected);

    bytes4 public constant ERROR_STRING_SELECTOR = bytes4(0x08c379a0); // Error(string)
    bytes4 public constant PANIC_UINT_SELECTOR = bytes4(0x4e487b71); // Panic(uint256)

    mapping(address => bool) public solvedError;
    mapping(address => bool) public solvedPanic;
    mapping(address => bool) public solvedCustom;

    event ErrorSelectorReported(address indexed user);
    event PanicSelectorReported(address indexed user);
    event CustomSelectorReported(address indexed user);

    /// @dev Always reverts with `Error(string)` (selector 0x08c379a0).
    function failWithRequire(uint256 v) external pure {
        require(v != 0, "value must be non-zero");
    }

    /// @dev When `cond == false`, reverts with `Panic(0x01)` (selector 0x4e487b71).
    function failWithAssert(bool cond) external pure {
        assert(cond);
    }

    /// @dev Reverts with the custom `InsufficientBalance(uint256,uint256)` error.
    function failWithCustomError(uint256 available, uint256 required) external pure {
        if (available < required) revert InsufficientBalance(available, required);
    }

    function reportErrorSelector(bytes4 selector) external {
        if (selector != ERROR_STRING_SELECTOR) revert WrongSelector(selector, ERROR_STRING_SELECTOR);
        solvedError[msg.sender] = true;
        emit ErrorSelectorReported(msg.sender);
    }

    function reportPanicSelector(bytes4 selector) external {
        if (selector != PANIC_UINT_SELECTOR) revert WrongSelector(selector, PANIC_UINT_SELECTOR);
        solvedPanic[msg.sender] = true;
        emit PanicSelectorReported(msg.sender);
    }

    function reportCustomSelector(bytes4 selector) external {
        bytes4 expected = InsufficientBalance.selector;
        if (selector != expected) revert WrongSelector(selector, expected);
        solvedCustom[msg.sender] = true;
        emit CustomSelectorReported(msg.sender);
    }

    function isSolved(address user) public view override returns (bool) {
        return solvedError[user] && solvedPanic[user] && solvedCustom[user];
    }
}
