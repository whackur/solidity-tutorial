// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice The logic contract — both `call` and `delegatecall` paths target
///         this code. Storage layout is mirrored by DelegateCaller.
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

/// @notice The caller contract — same storage slots 0/1/2 as DelegateLogic.
///         Routing helpers let you compare `call` vs `delegatecall`.
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

/// @notice Multi-tenant lab. Every user calls `createInstance()` once to
///         get a fresh (caller, logic) pair owned by them. The lab tracks
///         user instances in a mapping keyed by msg.sender and exposes
///         isSolved(address) for the web UI to grade.
///
///         Solve goal (per user):
///         - logicOf(user).number() == 42  (set via `call`, target writes to logic storage)
///         - callerOf(user).number() == 99 (set via `delegatecall`, logic code writes to caller storage)
contract DelegatecallLab is SolvableBase {
    struct Instance {
        DelegateCaller caller;
        DelegateLogic logic;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address caller, address logic);

    function createInstance() external returns (address caller, address logic) {
        require(address(_instances[msg.sender].caller) == address(0), "already created");
        DelegateCaller c = new DelegateCaller();
        DelegateLogic l = new DelegateLogic();
        _instances[msg.sender] = Instance(c, l);
        emit InstanceCreated(msg.sender, address(c), address(l));
        return (address(c), address(l));
    }

    function callerOf(address user) external view returns (DelegateCaller) {
        return _instances[user].caller;
    }

    function logicOf(address user) external view returns (DelegateLogic) {
        return _instances[user].logic;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.caller) == address(0)) return false;
        return inst.logic.number() == 42 && inst.caller.number() == 99;
    }
}
