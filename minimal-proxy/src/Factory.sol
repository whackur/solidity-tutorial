// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Implementation} from "./Implementation.sol";

contract Factory {
    address public implementation;

    event CloneCreated(address indexed clone, uint256 value);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createClone(uint256 _value) external returns (address) {
        address clone = Clones.clone(implementation);
        Implementation(clone).initialize(_value);
        emit CloneCreated(clone, _value);
        return clone;
    }

    function createDeterministicClone(uint256 _value, bytes32 _salt) external returns (address) {
        address clone = Clones.cloneDeterministic(implementation, _salt);
        Implementation(clone).initialize(_value);
        emit CloneCreated(clone, _value);
        return clone;
    }

    function predictDeterministicAddress(bytes32 _salt) external view returns (address) {
        return Clones.predictDeterministicAddress(implementation, _salt);
    }
}
