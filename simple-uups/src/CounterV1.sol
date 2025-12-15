// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from CounterV1
contract CounterV1 is Initializable, UUPSUpgradeable {
    uint256 public count;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        owner = initialOwner;
    }

    function increment() public {
        count += 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
