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

    function _leaf(address account, uint256 registrationCounter) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, registrationCounter))));
    }

    function _rootAtZero(address account, uint256 registrationCounter, bytes32 sibling)
        internal
        pure
        returns (bytes32)
    {
        bytes32 n0 = keccak256(abi.encode(_leaf(account, registrationCounter), sibling));
        bytes32 n1 = keccak256(abi.encode(n0, bytes32(0)));
        return keccak256(abi.encode(n1, bytes32(0)));
    }

    function _proof(bytes32 sibling) internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](3);
        proof[0] = sibling;
    }

    function test_ConstructorStartsWithIndependentEmptyState() public {
        assertEq(allowlist.LEAF_COUNT(), 8);
        assertEq(allowlist.PROOF_LENGTH(), 3);
        assertEq(allowlist.committedRoot(alice), bytes32(0));
        assertEq(allowlist.counter(alice), 0);
        assertFalse(allowlist.isAllowed(alice));
        assertEq(allowlist.committedRoot(bob), bytes32(0));
        assertEq(allowlist.counter(bob), 0);
        assertFalse(allowlist.isAllowed(bob));
    }

    function test_LeafForUsesDoubleHashAndCounter() public view {
        bytes32 inner = keccak256(abi.encode(alice, uint256(0)));
        assertEq(
            allowlist.leafFor(alice, 0), keccak256(bytes.concat(keccak256(abi.encode(alice, 0))))
        );
        assertEq(allowlist.leafFor(alice, 0), keccak256(bytes.concat(inner)));
        assertTrue(allowlist.leafFor(alice, 0) != allowlist.leafFor(alice, 1));
    }

    function test_UsersCommitRootsAndRegisterWithIsolatedCounters() public {
        bytes32 aliceSibling = _leaf(carol, 0);
        bytes32 bobSibling = _leaf(carol, 0);
        bytes32 aliceRoot = _rootAtZero(alice, 0, aliceSibling);
        bytes32 bobRoot = _rootAtZero(bob, 0, bobSibling);

        vm.prank(alice);
        allowlist.commitRoot(aliceRoot);
        vm.prank(bob);
        allowlist.commitRoot(bobRoot);

        vm.prank(alice);
        allowlist.register(0, _proof(aliceSibling));
        assertTrue(allowlist.isAllowed(alice));
        assertEq(allowlist.counter(alice), 1);
        assertEq(allowlist.committedRoot(alice), aliceRoot);
        assertFalse(allowlist.isAllowed(bob));
        assertEq(allowlist.counter(bob), 0);
        assertEq(allowlist.committedRoot(bob), bobRoot);

        vm.prank(bob);
        allowlist.register(0, _proof(bobSibling));
        assertTrue(allowlist.isAllowed(bob));
        assertEq(allowlist.counter(bob), 1);
        assertEq(allowlist.counter(alice), 1);
    }

    function test_RevertWhen_RootIsUnset() public {
        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.RootNotSet.selector);
        allowlist.register(0, new bytes32[](0));
    }

    function test_RevertWhen_ProofLengthIsNotThree() public {
        vm.prank(alice);
        allowlist.commitRoot(_rootAtZero(alice, 0, bytes32(0)));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.BadProofLength.selector, 0, 3));
        allowlist.register(0, new bytes32[](0));

        bytes32[] memory tooLongProof = new bytes32[](4);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.BadProofLength.selector, 4, 3));
        allowlist.register(0, tooLongProof);
    }

    function test_RevertWhen_IndexIsOutOfRange() public {
        bytes32[] memory proof = new bytes32[](3);
        vm.prank(alice);
        allowlist.commitRoot(_rootAtZero(alice, 0, bytes32(0)));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MerkleAllowlist.IndexOutOfRange.selector, 8, 8));
        allowlist.register(8, proof);
    }

    function test_RevertWhen_ProofIsInvalidWithoutIncrementingCounter() public {
        bytes32 sibling = _leaf(carol, 0);
        bytes32 root = _rootAtZero(alice, 0, sibling);
        vm.prank(alice);
        allowlist.commitRoot(root);

        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(0, _proof(_leaf(bob, 0)));

        assertEq(allowlist.counter(alice), 0);
        assertFalse(allowlist.isAllowed(alice));
    }

    function test_RevertWhen_OldProofIsReplayedAfterCounterIncrement() public {
        bytes32 firstSibling = _leaf(carol, 0);
        bytes32[] memory firstProof = _proof(firstSibling);

        vm.startPrank(alice);
        allowlist.commitRoot(_rootAtZero(alice, 0, firstProof[0]));
        allowlist.register(0, firstProof);

        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(0, firstProof);
        vm.stopPrank();

        assertEq(allowlist.counter(alice), 1);
        assertTrue(allowlist.isAllowed(alice));
    }

    function test_DirectionalIndexOrderMatchesQ27() public {
        bytes32 sibling = _leaf(carol, 0);
        bytes32 leaf = _leaf(alice, 0);
        bytes32[] memory proof = _proof(sibling);
        bytes32 n0 = keccak256(abi.encode(sibling, leaf));
        bytes32 n1 = keccak256(abi.encode(n0, bytes32(0)));
        bytes32 expected = keccak256(abi.encode(n1, bytes32(0)));

        assertEq(allowlist.computeRoot(leaf, 1, proof), expected);

        vm.prank(alice);
        allowlist.commitRoot(expected);
        vm.prank(alice);
        allowlist.register(1, proof);
        assertEq(allowlist.counter(alice), 1);
    }

    function test_MultiLevelDirectionBitsMatchQ27() public {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = _leaf(bob, 10);
        proof[1] = _leaf(carol, 11);
        proof[2] = _leaf(bob, 12);
        bytes32 leaf = _leaf(alice, 0);
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

        assertEq(allowlist.counter(alice), 1);
        assertTrue(allowlist.isAllowed(alice));
    }

    function test_RevertWhen_DirectionalIndexIsWrong() public {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = _leaf(bob, 10);
        proof[1] = _leaf(carol, 11);
        proof[2] = _leaf(bob, 12);
        bytes32 leaf = _leaf(alice, 0);
        bytes32 n0 = keccak256(abi.encode(proof[0], leaf));
        bytes32 n1 = keccak256(abi.encode(n0, proof[1]));
        bytes32 root = keccak256(abi.encode(proof[2], n1));

        vm.prank(alice);
        allowlist.commitRoot(root);
        vm.prank(alice);
        vm.expectRevert(MerkleAllowlist.InvalidProof.selector);
        allowlist.register(4, proof);

        assertEq(allowlist.counter(alice), 0);
        assertFalse(allowlist.isAllowed(alice));
    }

    function test_RepeatedRegistrationSucceedsAfterNewCommit() public {
        bytes32 firstSibling = _leaf(carol, 0);
        bytes32 firstRoot = _rootAtZero(alice, 0, firstSibling);

        vm.startPrank(alice);
        allowlist.commitRoot(firstRoot);
        allowlist.register(0, _proof(firstSibling));
        assertEq(allowlist.counter(alice), 1);
        assertTrue(allowlist.isAllowed(alice));

        bytes32 secondSibling = _leaf(carol, 99);
        bytes32[] memory secondProof = _proof(secondSibling);
        bytes32 secondN0 = keccak256(abi.encode(secondProof[0], _leaf(alice, 1)));
        bytes32 secondN1 = keccak256(abi.encode(secondN0, bytes32(0)));
        bytes32 secondRoot = keccak256(abi.encode(secondN1, bytes32(0)));
        allowlist.commitRoot(secondRoot);
        allowlist.register(1, secondProof);
        vm.stopPrank();

        assertEq(allowlist.counter(alice), 2);
        assertTrue(allowlist.isAllowed(alice));
    }

    function test_RevokeIsSelfOnlyAndDoesNotResetCounter() public {
        bytes32 sibling = _leaf(carol, 0);
        bytes32 root = _rootAtZero(alice, 0, sibling);

        vm.startPrank(alice);
        allowlist.commitRoot(root);
        allowlist.register(0, _proof(sibling));
        allowlist.revoke();
        vm.stopPrank();

        assertFalse(allowlist.isAllowed(alice));
        assertEq(allowlist.counter(alice), 1);

        vm.prank(bob);
        vm.expectRevert(MerkleAllowlist.NotRegistered.selector);
        allowlist.revoke();
    }

    function test_RevokeThenNewCounterProofRestoresAccess() public {
        bytes32 firstSibling = _leaf(carol, 0);
        vm.startPrank(alice);
        allowlist.commitRoot(_rootAtZero(alice, 0, firstSibling));
        allowlist.register(0, _proof(firstSibling));
        allowlist.revoke();

        bytes32 nextSibling = _leaf(carol, 1);
        allowlist.commitRoot(_rootAtZero(alice, 1, nextSibling));
        allowlist.register(0, _proof(nextSibling));
        vm.stopPrank();

        assertTrue(allowlist.isAllowed(alice));
        assertEq(allowlist.counter(alice), 2);
    }
}
