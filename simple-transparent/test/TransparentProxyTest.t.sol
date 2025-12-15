// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TransparentProxyTest is Test {
    Box public implementationV1;
    BoxV2 public implementationV2;
    TransparentUpgradeableProxy public proxy;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        // Deploy Implementation V1
        implementationV1 = new Box();

        // Encode initialization data
        bytes memory initData = abi.encodeCall(Box.initialize, (42));

        // Deploy Proxy
        // Owner of the ProxyAdmin will be 'owner' (this contract)
        proxy = new TransparentUpgradeableProxy(address(implementationV1), owner, initData);
    }

    function test_Deployment() public {
        // Cast proxy to Box interface
        Box box = Box(address(proxy));

        assertEq(box.retrieve(), 42);
    }

    function test_UpgradeToV2() public {
        // Deploy Implementation V2
        implementationV2 = new BoxV2();

        // Get ProxyAdmin address
        // Can be retrieved? In OZ 5.0 we don't have a direct getter easily unless we compute it or event?
        // Actually, we are the owner of the ProxyAdmin.
        // But we need to call `upgradeAndCall` on the proxy? No, on the *ProxyAdmin*?
        // Wait, standard Transparent Proxy pattern:
        // Users call Proxy -> delegatecall to Implementation.
        // Admin calls Proxy -> if recognized as admin, calls Proxy functions (upgrade etc).
        // BUT OZ 5.0 changed this.

        // In OZ 5.0, TransparentUpgradeableProxy does NOT handle admin logic in the fallback.
        // It uses a dedicated ProxyAdmin contract.
        // The `msg.sender` must be the ProxyAdmin contract to upgrade.
        // So we need to find the ProxyAdmin contract address or use `ProxyAdmin` interface to call it?
        // No, we (owner) call functions on `ProxyAdmin`, which then calls `upgrade` on the Proxy.
        // But we don't know the ProxyAdmin address easily from the test directly unless we emit it or predict it?
        // Ah, `TransparentUpgradeableProxy` does not expose `admin()` easily?

        // Wait, let's look at `TransparentUpgradeableProxy` source or helper.
        // Actually, for testing we can fetch the admin using storage slot if needed, or...
        // Wait, checking OZ 5.0 docs.
        // `TransparentUpgradeableProxy` creates a `ProxyAdmin` in constructor.
        // We can't easily get it?
        // Actually there is a library `ProxyAdmin`? No that's the contract.

        // Let's use `ITransparentUpgradeableProxy` cast?
        // The ERC1967Utils might help.

        // Let's look at how to get admin.
        // Easiest is to read the admin storage slot.
        // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address adminAddr = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));

        console.log("ProxyAdmin address:", adminAddr);

        ProxyAdmin proxyAdmin = ProxyAdmin(adminAddr);

        // Upgrade
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(implementationV2), ""
        );

        // Verify V2 functionality
        BoxV2 boxV2 = BoxV2(address(proxy));
        boxV2.increment();
        assertEq(boxV2.retrieve(), 43);
    }
}
