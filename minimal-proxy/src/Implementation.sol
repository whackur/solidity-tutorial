// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Implementation is Initializable {
    uint256 public value;
    address public owner;

    event Initialized(uint256 value, address owner);

    function initialize(uint256 _value) public initializer {
        value = _value;
        owner = msg.sender;
        emit Initialized(_value, msg.sender);
    }
}
