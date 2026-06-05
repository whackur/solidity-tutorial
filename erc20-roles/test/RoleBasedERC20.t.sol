// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {RoleBasedERC20} from "../src/RoleBasedERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RoleBasedERC20Test is Test {
    RoleBasedERC20 internal token;

    address internal admin = address(this);
    address internal minter = address(0x111);
    address internal pauser = address(0x222);
    address internal alice = address(0xA11CE);
    address internal mallory = address(0xBAD);

    // Cached in setUp: calling token.MINTER_ROLE() between vm.prank and the
    // call under test would consume the prank on the view call instead.
    bytes32 internal adminRole;
    bytes32 internal minterRole;
    bytes32 internal pauserRole;

    function setUp() public {
        token = new RoleBasedERC20(admin);
        adminRole = token.DEFAULT_ADMIN_ROLE();
        minterRole = token.MINTER_ROLE();
        pauserRole = token.PAUSER_ROLE();
        token.grantRole(minterRole, minter);
        token.grantRole(pauserRole, pauser);
    }

    // ----- Role-gated mint -----

    function test_MinterCanMint() public {
        vm.prank(minter);
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
    }

    function test_NonMinterCannotMint() public {
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, mallory, minterRole
            )
        );
        token.mint(mallory, 1);
    }

    // ----- Role-gated pause -----

    function test_PauserCanPauseAndUnpause() public {
        vm.prank(minter);
        token.mint(alice, 1000);

        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(mallory, 100);

        vm.prank(pauser);
        token.unpause();

        vm.prank(alice);
        token.transfer(mallory, 100);
        assertEq(token.balanceOf(mallory), 100);
    }

    function test_NonPauserCannotPause() public {
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, mallory, pauserRole
            )
        );
        token.pause();
    }

    // ----- Admin manages roles -----

    function test_AdminGrantsAndRevokes() public {
        token.revokeRole(minterRole, minter);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, minter, minterRole
            )
        );
        token.mint(alice, 1);
    }

    function test_NonAdminCannotGrant() public {
        // grantRole is gated by the role's admin role (DEFAULT_ADMIN_ROLE here)
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, mallory, adminRole
            )
        );
        token.grantRole(minterRole, mallory);
    }

    // ----- EnumerableSet-backed membership enumeration -----

    function test_RoleMembersAreEnumerable() public view {
        // MINTER_ROLE holders: admin (constructor) and minter (setUp)
        assertEq(token.getRoleMemberCount(minterRole), 2);
        assertEq(token.getRoleMember(minterRole, 0), admin);
        assertEq(token.getRoleMember(minterRole, 1), minter);

        address[] memory members = token.getRoleMembers(pauserRole);
        assertEq(members.length, 2);
        assertEq(members[0], admin);
        assertEq(members[1], pauser);
    }

    function test_RevokeShrinksEnumeration() public {
        token.revokeRole(minterRole, minter);
        assertEq(token.getRoleMemberCount(minterRole), 1);
        assertEq(token.getRoleMember(minterRole, 0), admin);
    }

    function test_RenounceRemovesSelf() public {
        // renounceRole lets an account drop its own privilege (key compromise drill)
        vm.prank(minter);
        token.renounceRole(minterRole, minter);
        assertFalse(token.hasRole(minterRole, minter));
        assertEq(token.getRoleMemberCount(minterRole), 1);
    }
}
