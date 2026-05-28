// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q11VulnerableRegistry} from "../src/Setup.sol";

contract Q11AccessControlPublicTest is Test {
    Q11VulnerableRegistry internal registry;
    address internal alice = makeAddr("alice");

    function setUp() public {
        registry = new Q11VulnerableRegistry();
    }

    function test_InitialStateIsUnsolved() public view {
        assertEq(registry.owner(), address(this));
        assertFalse(registry.adminPromoted(alice));
        assertFalse(registry.isSolved(alice));
    }

    function test_UnpromotedUserCannotClaim() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not promoted"));
        registry.claimAdmin();
    }
}
