// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";
import {MerkleTreeLib} from "./MerkleTreeLib.sol";

contract MerkleAllowlistTest is Test {
    using MerkleTreeLib for bytes32[];

    MerkleAllowlist internal allowlist;
    address internal owner = makeAddr("owner");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal mallory = makeAddr("mallory");

    address internal dave = makeAddr("dave");

    bytes32[] internal leaves;

    function setUp() public {
        leaves.push(_leaf(alice));
        leaves.push(_leaf(bob));
        leaves.push(_leaf(carol));
        leaves.push(_leaf(dave));

        allowlist = new MerkleAllowlist(leaves.root(), owner);
    }

    function _leaf(address a) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(a))));
    }

    // --- registration -----------------------------------------------------

    function test_ValidProofRegisters() public {
        assertFalse(allowlist.isAllowed(alice));

        vm.prank(alice);
        allowlist.register(leaves.proof(0));

        assertTrue(allowlist.isAllowed(alice));
    }

    function test_RevertWhen_ProofBelongsToAnotherAddress() public {
        // Bob presents Alice's proof. The leaf is derived from msg.sender, so
        // the path no longer reconstructs the root.
        vm.prank(bob);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(leaves.proof(0));
    }

    function test_RevertWhen_NotInTree() public {
        vm.prank(mallory);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(leaves.proof(0));
    }

    function test_RevertWhen_RegisteringTwice() public {
        vm.startPrank(alice);
        allowlist.register(leaves.proof(0));
        vm.expectRevert(MerkleAllowlist.AlreadyRegistered.selector);
        allowlist.register(leaves.proof(0));
        vm.stopPrank();
    }

    function test_RevertWhen_RootUnset() public {
        MerkleAllowlist empty = new MerkleAllowlist(bytes32(0), owner);
        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.RootNotSet.selector);
        empty.register(leaves.proof(0));
    }

    // --- the root-rotation trap -------------------------------------------

    function test_RotatingRootDoesNotRevokeExistingRegistrations() public {
        vm.prank(alice);
        allowlist.register(leaves.proof(0));
        assertTrue(allowlist.isAllowed(alice));

        // New tree without Alice.
        bytes32[] memory next = new bytes32[](2);
        next[0] = _leaf(bob);
        next[1] = _leaf(carol);

        vm.prank(owner);
        allowlist.setAllowlistRoot(MerkleTreeLib.root(next));

        // This is the trap: Alice is gone from the tree but still allowed.
        assertTrue(allowlist.isAllowed(alice), "root rotation does not un-register");
    }

    function test_OldProofStopsWorkingAfterRotation() public {
        bytes32[] memory next = new bytes32[](2);
        next[0] = _leaf(bob);
        next[1] = _leaf(carol);

        vm.prank(owner);
        allowlist.setAllowlistRoot(MerkleTreeLib.root(next));

        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(leaves.proof(0));
    }

    function test_RevokeClearsAccess() public {
        vm.prank(alice);
        allowlist.register(leaves.proof(0));

        vm.prank(owner);
        allowlist.revoke(alice);

        assertFalse(allowlist.isAllowed(alice));
    }

    function test_RevertWhen_RevokingUnregistered() public {
        vm.prank(owner);
        vm.expectRevert(MerkleAllowlist.NotRegistered.selector);
        allowlist.revoke(mallory);
    }

    // --- access control ---------------------------------------------------

    function test_RevertWhen_NonOwnerRotatesRoot() public {
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, mallory)
        );
        allowlist.setAllowlistRoot(bytes32(uint256(1)));
    }

    function test_RevertWhen_NonOwnerRevokes() public {
        vm.prank(alice);
        allowlist.register(leaves.proof(0));

        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, mallory)
        );
        allowlist.revoke(alice);
    }

    function test_OwnerCanAllowAndBlockSystemAddress() public {
        address systemContract = makeAddr("systemContract");

        vm.prank(owner);
        allowlist.setSystemAddress(systemContract, true);
        assertTrue(allowlist.isAllowed(systemContract));

        vm.prank(owner);
        allowlist.setSystemAddress(systemContract, false);
        assertFalse(allowlist.isAllowed(systemContract));
    }

    function test_RevertWhen_NonOwnerSetsSystemAddress() public {
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, mallory)
        );
        allowlist.setSystemAddress(makeAddr("systemContract"), true);
    }

    // --- every member can register ----------------------------------------

    function test_EveryLeafCanRegister() public {
        address[4] memory members = [alice, bob, carol, dave];
        for (uint256 i = 0; i < members.length; i++) {
            vm.prank(members[i]);
            allowlist.register(leaves.proof(i));
            assertTrue(allowlist.isAllowed(members[i]));
        }
    }
}
