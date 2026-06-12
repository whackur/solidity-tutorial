// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q12TxOriginLab, Q12TxOriginVault, Q12Phisher, Q12MockToken} from "../src/Setup.sol";

contract Q12TxOriginPublicTest is Test {
    Q12TxOriginLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q12TxOriginLab();
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice, alice);
        (address vault, address phisher) = lab.createInstance();

        assertTrue(vault != address(0));
        assertTrue(phisher != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice, alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }

    /// @notice Drives the phishing exploit end-to-end. The lure runs in a tx
    ///         whose origin is the owner, so the tx.origin-gated vault drains
    ///         its token balance to the beneficiary. Proves the tokenized
    ///         version still flips `isSolved`.
    function test_PhishingDrainsToken() public {
        vm.prank(alice, alice);
        (address vaultAddr, address phisherAddr) = lab.createInstance();
        Q12TxOriginVault vault = Q12TxOriginVault(vaultAddr);
        Q12Phisher phisher = Q12Phisher(phisherAddr);
        Q12MockToken token = vault.token();

        assertEq(token.balanceOf(address(vault)), lab.SEED());

        // tx.origin == alice == owner satisfies the vault's broken check.
        vm.prank(alice, alice);
        phisher.claimFreeAirdrop();

        assertEq(token.balanceOf(address(vault)), 0);
        assertTrue(phisher.airdropClaimed());
        assertTrue(lab.isSolved(alice));
    }
}
