// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Script, console} from 'forge-std/Script.sol';
import {Implementation} from '../src/Implementation.sol';
import {Factory} from '../src/Factory.sol';

contract DeployScript is Script {
  function setUp() public {}

  function run() public {
    string memory mnemonic = vm.envString('DEPLOYER_MNEMONIC');
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

    vm.startBroadcast(deployerPrivateKey);

    Implementation implementation = new Implementation();
    console.log('Implementation deployed at:', address(implementation));

    Factory factory = new Factory(address(implementation));
    console.log('Factory deployed at:', address(factory));

    vm.stopBroadcast();
  }
}
