// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Implementation.sol";

contract ClonesTest is Test {
    Factory public factory;
    Implementation public implementation;

    function setUp() public {
        implementation = new Implementation();
        factory = new Factory(address(implementation));
    }

    function testCreateClone() public {
        uint256 value = 123;
        address cloneAddress = factory.createClone(value);

        Implementation clone = Implementation(cloneAddress);
        assertEq(clone.value(), value);
        assertEq(clone.owner(), address(factory));
    }

    function testCreateDeterministicClone() public {
        uint256 value = 456;
        bytes32 salt = keccak256(abi.encodePacked("mysalt"));

        address predicted = factory.predictDeterministicAddress(salt);
        address cloneAddress = factory.createDeterministicClone(value, salt);

        assertEq(predicted, cloneAddress);

        Implementation clone = Implementation(cloneAddress);
        assertEq(clone.value(), value);
        assertEq(clone.owner(), address(factory));
    }

    function testMultipleClonesExepctDifferentAddresses() public {
        address clone1 = factory.createClone(1);
        address clone2 = factory.createClone(1);
        assertTrue(clone1 != clone2);
    }
}
