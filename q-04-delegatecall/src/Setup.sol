// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @dev Local copy of ../tx-basics/src/DelegatecallDemo.sol — kept self-contained.

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

contract DelegateCaller {
    uint256 public number;
    address public sender;
    uint256 public value;

    function setVarsViaCall(DelegateLogic logic, uint256 newNumber)
        external
        payable
        returns (uint256, address, uint256)
    {
        return logic.setVars{value: msg.value}(newNumber);
    }

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
