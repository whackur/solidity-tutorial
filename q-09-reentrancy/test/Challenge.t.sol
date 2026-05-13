// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {VulnerableVault, IVulnerableVault} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q09ReentrancyTest is Test {
    VulnerableVault internal vault;
    Solution internal sol;

    address internal victim = address(0xDEAD);

    function setUp() public {
        vault = new VulnerableVault();
        sol = new Solution();

        // 10 ETH from a good-faith depositor
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vault.deposit{value: 10 ether}();

        // 1 ETH bait for the attacker
        vm.deal(address(this), 1 ether);
        sol.setVault(IVulnerableVault(address(vault)));
    }

    function test_VaultDrained() public {
        sol.attack{value: 1 ether}();
        assertEq(address(vault).balance, 0, "vault is empty");
    }

    function test_AttackerHolds11Eth() public {
        sol.attack{value: 1 ether}();
        assertGe(address(sol).balance, 11 ether, "attacker took bait + victim funds");
    }
}
