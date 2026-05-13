// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {OwnableVault} from "../src/OwnableVault.sol";
import {RoleManagedVault} from "../src/RoleManagedVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract OwnableVaultTest is Test {
    OwnableVault internal vault;
    address internal owner = address(this);
    address internal alice = address(0xA11CE);

    function setUp() public {
        vault = new OwnableVault(owner);
    }

    function test_OwnerCanMint() public {
        vault.mint(alice, 1_000);
        assertEq(vault.balanceOf(alice), 1_000);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        vault.mint(alice, 1_000);
    }
}

contract RoleManagedVaultTest is Test {
    RoleManagedVault internal vault;
    address internal admin = address(this);
    address internal minter = address(0xBEEF);
    address internal pauser = address(0xCAFE);
    address internal alice = address(0xA11CE);

    function setUp() public {
        vault = new RoleManagedVault(admin);
        vault.grantRole(vault.MINTER_ROLE(), minter);
        vault.grantRole(vault.PAUSER_ROLE(), pauser);
    }

    function test_MinterCanMintButCannotPause() public {
        vm.prank(minter);
        vault.mint(alice, 1_000);
        assertEq(vault.balanceOf(alice), 1_000);

        // If `vm.prank` is placed right before `vm.expectRevert`, the prank can be consumed by the
        // expectRevert cheatcode call itself. → register expectRevert first, then prank, then call.
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                vault.PAUSER_ROLE()
            )
        );
        vm.prank(minter);
        vault.pause();
    }

    function test_PauserCanPauseButCannotMint() public {
        vm.prank(pauser);
        vault.pause();
        assertTrue(vault.paused());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                pauser,
                vault.MINTER_ROLE()
            )
        );
        vm.prank(pauser);
        vault.mint(alice, 1);
    }

    function test_AdminCanRevokeRole() public {
        vault.revokeRole(vault.MINTER_ROLE(), minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                vault.MINTER_ROLE()
            )
        );
        vm.prank(minter);
        vault.mint(alice, 1);
    }

    function test_PausedBlocksMint() public {
        vm.prank(pauser);
        vault.pause();
        vm.prank(minter);
        vm.expectRevert(bytes("paused"));
        vault.mint(alice, 1);
    }
}
