// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Script, console} from "forge-std/Script.sol";
import {Box} from "../src/Box.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        string memory mnemonic = vm.envString("DEPLOYER_MNEMONIC");
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Implementation
        Box implementation = new Box();
        console.log("Implementation V1 deployed at:", address(implementation));

        // Encode initialization data
        bytes memory initData = abi.encodeCall(Box.initialize, (42));

        // Deploy Proxy
        // In OZ 5.0, Constructor: (address _logic, address initialOwner, bytes memory _data)
        // initialOwner will be the owner of the *ProxyAdmin* contract that manages this proxy.
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), deployer, initData);
        console.log("Transparent Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
