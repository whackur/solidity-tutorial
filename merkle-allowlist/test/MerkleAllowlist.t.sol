// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";

contract MerkleAllowlistTest is Test {
    MerkleAllowlist internal allowlist;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        allowlist = new MerkleAllowlist();
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    /// @dev Builds the full eight-leaf tree the classroom shape expects.
    function _root(bytes32[8] memory leaves) internal pure returns (bytes32) {
        bytes32[4] memory level1;
        for (uint256 i = 0; i < 4; i++) {
            level1[i] = keccak256(abi.encode(leaves[i * 2], leaves[i * 2 + 1]));
        }
        bytes32 left = keccak256(abi.encode(level1[0], level1[1]));
        bytes32 right = keccak256(abi.encode(level1[2], level1[3]));
        return keccak256(abi.encode(left, right));
    }

    /// @dev Collects the direction-aware sibling path for one slot.
    function _proof(bytes32[8] memory leaves, uint256 index)
        internal
        pure
        returns (bytes32[] memory proof)
    {
        proof = new bytes32[](3);
        proof[0] = leaves[index ^ 1];

        bytes32[4] memory level1;
        for (uint256 i = 0; i < 4; i++) {
            level1[i] = keccak256(abi.encode(leaves[i * 2], leaves[i * 2 + 1]));
        }
        proof[1] = level1[(index / 2) ^ 1];

        bytes32[2] memory level2;
        level2[0] = keccak256(abi.encode(level1[0], level1[1]));
        level2[1] = keccak256(abi.encode(level1[2], level1[3]));
        proof[2] = level2[(index / 4) ^ 1];
    }

    /// @dev The shared classroom list: eight addresses, one per slot.
    function _members() internal returns (bytes32[8] memory leaves, address[8] memory members) {
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        for (uint256 slot = 3; slot < 8; slot++) {
            members[slot] = makeAddr(string.concat("member", vm.toString(slot)));
        }
        for (uint256 slot = 0; slot < 8; slot++) {
            leaves[slot] = _leaf(members[slot]);
        }
    }

    function test_ConstructorStartsWithIndependentEmptyState() public view {
        assertEq(allowlist.LEAF_COUNT(), 8);
        assertEq(allowlist.PROOF_LENGTH(), 3);
        assertEq(allowlist.committedRoot(alice), bytes32(0));
        assertFalse(allowlist.isAllowed(alice));
        assertEq(allowlist.committedRoot(bob), bytes32(0));
        assertFalse(allowlist.isAllowed(bob));
    }

    function test_LeafForIsTheDoubleHashedAddress() public view {
        assertEq(allowlist.leafFor(alice), keccak256(bytes.concat(keccak256(abi.encode(alice)))));
        assertTrue(allowlist.leafFor(alice) != allowlist.leafFor(bob));
    }

    function test_GroupSharesOneRootAndEachMemberRegistersOwnSlot() public {
        (bytes32[8] memory leaves, address[8] memory members) = _members();
        bytes32 root = _root(leaves);

        // Every member commits the same root: the list is shared, the commit
        // is not, because there is no owner.
        for (uint256 slot = 0; slot < 8; slot++) {
            vm.prank(members[slot]);
            allowlist.commitRoot(root);
        }

        for (uint256 slot = 0; slot < 8; slot++) {
            vm.prank(members[slot]);
            allowlist.register(slot, _proof(leaves, slot));
            assertTrue(allowlist.isAllowed(members[slot]));
        }

        for (uint256 slot = 0; slot < 8; slot++) {
            assertEq(allowlist.committedRoot(members[slot]), root);
        }
    }

    function test_RevertWhen_MemberUsesAnotherMembersSlot() public {
        (bytes32[8] memory leaves, address[8] memory members) = _members();
        bytes32 root = _root(leaves);

        vm.prank(members[0]);
        allowlist.commitRoot(root);

        // Slot 1 belongs to another address, so its path cannot lift alice's leaf.
        vm.prank(members[0]);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(1, _proof(leaves, 1));

        assertFalse(allowlist.isAllowed(members[0]));
    }

    function test_RevertWhen_RootIsUnset() public {
        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.RootNotSet.selector);
        allowlist.register(0, new bytes32[](0));
    }

    function test_RevertWhen_ProofLengthIsNotThree() public {
        (bytes32[8] memory leaves,) = _members();
        vm.prank(alice);
        allowlist.commitRoot(_root(leaves));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.BadProofLength.selector, 0, 3));
        allowlist.register(0, new bytes32[](0));

        bytes32[] memory tooLongProof = new bytes32[](4);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.BadProofLength.selector, 4, 3));
        allowlist.register(0, tooLongProof);
    }

    function test_RevertWhen_IndexIsOutOfRange() public {
        (bytes32[8] memory leaves,) = _members();
        bytes32[] memory proof = new bytes32[](3);
        vm.prank(alice);
        allowlist.commitRoot(_root(leaves));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.IndexOutOfRange.selector, 8, 8));
        allowlist.register(8, proof);
    }

    function test_RevertWhen_ProofIsInvalid() public {
        (bytes32[8] memory leaves,) = _members();
        vm.prank(alice);
        allowlist.commitRoot(_root(leaves));

        bytes32[] memory wrongProof = _proof(leaves, 0);
        wrongProof[0] = _leaf(makeAddr("stranger"));

        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(0, wrongProof);

        assertFalse(allowlist.isAllowed(alice));
    }

    function test_RevertWhen_RegisteringTwiceWithoutRevoking() public {
        (bytes32[8] memory leaves,) = _members();
        bytes32 root = _root(leaves);
        bytes32[] memory proof = _proof(leaves, 0);

        vm.startPrank(alice);
        allowlist.commitRoot(root);
        allowlist.register(0, proof);

        vm.expectRevert(MerkleAllowlist.AlreadyRegistered.selector);
        allowlist.register(0, proof);
        vm.stopPrank();

        assertTrue(allowlist.isAllowed(alice));
    }

    function test_RevokeThenSameProofRegistersAgain() public {
        (bytes32[8] memory leaves,) = _members();
        bytes32 root = _root(leaves);
        bytes32[] memory proof = _proof(leaves, 0);

        vm.startPrank(alice);
        allowlist.commitRoot(root);
        allowlist.register(0, proof);
        allowlist.revoke();
        assertFalse(allowlist.isAllowed(alice));

        // The list did not change, so the same path still proves membership.
        allowlist.register(0, proof);
        vm.stopPrank();

        assertTrue(allowlist.isAllowed(alice));
        assertEq(allowlist.committedRoot(alice), root);
    }

    function test_RevokeIsSelfOnly() public {
        (bytes32[8] memory leaves,) = _members();
        vm.startPrank(alice);
        allowlist.commitRoot(_root(leaves));
        allowlist.register(0, _proof(leaves, 0));
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(MerkleAllowlist.NotRegistered.selector);
        allowlist.revoke();

        assertTrue(allowlist.isAllowed(alice), "nobody else can remove alice");
    }

    function test_RotatingRootDoesNotRevokeAnExistingRegistration() public {
        (bytes32[8] memory leaves,) = _members();

        vm.startPrank(alice);
        allowlist.commitRoot(_root(leaves));
        allowlist.register(0, _proof(leaves, 0));

        // A list that no longer contains alice.
        bytes32[8] memory rotated = leaves;
        rotated[0] = _leaf(makeAddr("replacement"));
        allowlist.commitRoot(_root(rotated));
        vm.stopPrank();

        assertTrue(allowlist.isAllowed(alice), "root rotation is not a removal");
    }

    function test_DirectionalIndexOrderMatchesQ27() public view {
        bytes32 sibling = _leaf(carol);
        bytes32 leaf = _leaf(alice);
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = sibling;

        bytes32 leftFirst = keccak256(abi.encode(leaf, sibling));
        bytes32 rightFirst = keccak256(abi.encode(sibling, leaf));
        assertTrue(leftFirst != rightFirst, "encode order must matter");

        bytes32 n1 = keccak256(abi.encode(leftFirst, bytes32(0)));
        assertEq(allowlist.computeRoot(leaf, 0, proof), keccak256(abi.encode(n1, bytes32(0))));

        bytes32 m1 = keccak256(abi.encode(rightFirst, bytes32(0)));
        assertEq(allowlist.computeRoot(leaf, 1, proof), keccak256(abi.encode(m1, bytes32(0))));
    }

    function test_MultiLevelDirectionBitsMatchQ27() public {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = _leaf(bob);
        proof[1] = _leaf(carol);
        proof[2] = _leaf(makeAddr("dave"));
        bytes32 leaf = _leaf(alice);
        uint256 index = 5; // binary 101: right, left, right
        bytes32 n0 = keccak256(abi.encode(proof[0], leaf));
        bytes32 n1 = keccak256(abi.encode(n0, proof[1]));
        bytes32 expected = keccak256(abi.encode(proof[2], n1));

        assertEq(allowlist.computeRoot(leaf, index, proof), expected);

        vm.startPrank(alice);
        allowlist.commitRoot(expected);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(1, proof);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(4, proof);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(7, proof);
        allowlist.register(index, proof);
        vm.stopPrank();

        assertTrue(allowlist.isAllowed(alice));
    }
}
