// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Box is Initializable {
    uint256 private _value;

    event ValueChanged(uint256 newValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialValue) public initializer {
        _value = initialValue;
        emit ValueChanged(initialValue);
    }

    function store(uint256 newValue) public {
        _value = newValue;
        emit ValueChanged(newValue);
    }

    function retrieve() public view returns (uint256) {
        return _value;
    }
}
