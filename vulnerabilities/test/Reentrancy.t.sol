// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {VulnerableVault} from "../src/reentrancy/VulnerableVault.sol";
import {SafeVault} from "../src/reentrancy/SafeVault.sol";
import {ReentrancyAttacker} from "../src/reentrancy/ReentrancyAttacker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ReentrancyTest is Test {
    address internal attackerEoa = address(0xBAD);

    function setUp() public {
        vm.deal(attackerEoa, 10 ether);
    }

    function test_VulnerableVaultIsDrained() public {
        VulnerableVault vault = new VulnerableVault();

        // Two normal users deposit 5 ETH each
        vm.deal(address(0xA1), 5 ether);
        vm.deal(address(0xA2), 5 ether);
        vm.prank(address(0xA1));
        vault.deposit{value: 5 ether}();
        vm.prank(address(0xA2));
        vault.deposit{value: 5 ether}();
        assertEq(address(vault).balance, 10 ether);

        // Attack: drain the vault with only 1 ETH
        vm.prank(attackerEoa);
        ReentrancyAttacker atk = new ReentrancyAttacker(address(vault));
        vm.prank(attackerEoa);
        atk.attack{value: 1 ether}();

        // The vault is drained to 0, and the attacker contract holds 11 ETH
        assertEq(address(vault).balance, 0);
        assertEq(address(atk).balance, 11 ether);
    }

    function test_SafeVaultBlocksAttack() public {
        SafeVault vault = new SafeVault();
        vm.deal(address(0xA1), 5 ether);
        vm.prank(address(0xA1));
        vault.deposit{value: 5 ether}();

        vm.prank(attackerEoa);
        ReentrancyAttacker atk = new ReentrancyAttacker(address(vault));

        // deposit/withdraw themselves are still possible on SafeVault, but nonReentrant blocks reentrancy
        // attack() itself reverts (reentrancy attempt)
        vm.prank(attackerEoa);
        vm.expectRevert();
        atk.attack{value: 1 ether}();

        // The normal user's balance remains intact
        assertEq(address(vault).balance, 5 ether);
    }
}
