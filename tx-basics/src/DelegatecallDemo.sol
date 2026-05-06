// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Logic contract used by {DelegateCaller} to compare `call` and
///         `delegatecall` side-by-side.
///
/// @dev The storage layout intentionally matches {DelegateCaller}. With a
///      normal `call`, writes update this contract. With `delegatecall`, the
///      same bytecode runs in the caller's storage, preserving the original
///      `msg.sender` and `msg.value`.
contract DelegateLogic {
    uint256 public number;
    address public sender;
    uint256 public value;

    function setVars(uint256 newNumber) external payable returns (uint256, address, uint256) {
        number = newNumber;
        sender = msg.sender;
        value = msg.value;

        return (number, sender, value);
    }
}

/// @notice Demonstrates the two low-level execution modes:
///         - `call`: execute target code in target storage.
///         - `delegatecall`: execute target code in this contract's storage.
///
/// @dev Never delegatecall into untrusted code. The target code can overwrite
///      any storage slot of this contract.
contract DelegateCaller {
    // Same slot order as DelegateLogic: slot 0, slot 1, slot 2.
    uint256 public number;
    address public sender;
    uint256 public value;

    /// @dev Normal call: mutates `logic` storage and transfers ETH to `logic`.
    function setVarsViaCall(DelegateLogic logic, uint256 newNumber)
        external
        payable
        returns (uint256, address, uint256)
    {
        return logic.setVars{value: msg.value}(newNumber);
    }

    /// @dev Delegatecall: mutates this contract's storage, keeps ETH here, and
    ///      preserves the external caller as `msg.sender` inside the logic code.
    function setVarsViaDelegatecall(address logic, uint256 newNumber)
        external
        payable
        returns (uint256, address, uint256)
    {
        bytes memory data = abi.encodeCall(DelegateLogic.setVars, (newNumber));
        (bool ok, bytes memory ret) = logic.delegatecall(data);
        require(ok, "delegatecall failed");

        return abi.decode(ret, (uint256, address, uint256));
    }
}
