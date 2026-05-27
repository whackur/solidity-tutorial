// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q11VulnerableRegistry} from "../src/Setup.sol";

contract Q11AccessControlTest is Test {
    Q11VulnerableRegistry internal registry;

    address internal deployer = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        registry = new Q11VulnerableRegistry();
        assertEq(registry.owner(), deployer, "owner is deployer");
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        registry.grantAdmin(user);
        registry.claimAdmin();
        vm.stopPrank();
    }

    function test_AliceSolves() public {
        _solve(alice);
        assertTrue(registry.isSolved(alice));
        assertTrue(registry.adminPromoted(alice));
        assertTrue(registry.solved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(registry.isSolved(alice));
        assertTrue(registry.isSolved(bob));
    }

    /// @notice Even though `grantAdmin` is unguarded, `claimAdmin` is
    ///         self-only — so another user cannot finalise a victim's slot.
    function test_GrantWithoutClaimDoesNotSolve() public {
        vm.prank(bob);
        registry.grantAdmin(alice); // bob "promotes" alice with the buggy setter
        assertTrue(registry.adminPromoted(alice));
        assertFalse(registry.isSolved(alice));
    }

    function test_ClaimWithoutPromotionReverts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not promoted"));
        registry.claimAdmin();
    }

    function test_RevokeRequiresOwner() public {
        vm.prank(alice);
        registry.grantAdmin(alice);
        vm.prank(bob);
        vm.expectRevert(bytes("not owner"));
        registry.revokeAdmin(alice);
        // contrast: deployer (owner) can revoke
        registry.revokeAdmin(alice);
        assertFalse(registry.adminPromoted(alice));
    }
}
