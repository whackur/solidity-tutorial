// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ISolvable} from "@common/ISolvable.sol";
import {Q27MerkleAllowlistLab} from "../src/Setup.sol";

/// @notice Smoke and interface tests. These deliberately stop short of
///         assembling a correct tree and claiming — the solve path is not
///         published in this repository.
contract ChallengeTest is Test {
    Q27MerkleAllowlistLab internal lab;

    address internal userA = makeAddr("userA");
    address internal userB = makeAddr("userB");

    function setUp() public {
        lab = new Q27MerkleAllowlistLab();
    }

    function _emptyProof() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function _proofOfLength(uint256 n) internal pure returns (bytes32[] memory p) {
        p = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            p[i] = bytes32(uint256(0xBAD00 + i));
        }
    }

    // --- constants --------------------------------------------------------

    function test_Constants() public view {
        assertEq(lab.LEAF_COUNT(), 8);
        assertEq(lab.PROOF_LENGTH(), 3);
        assertEq(lab.PEER_COUNT(), 7);
        assertEq(lab.PEER_COUNT() + 1, lab.LEAF_COUNT(), "peers plus caller fill the list");
        assertEq(1 << lab.PROOF_LENGTH(), lab.LEAF_COUNT(), "depth must match leaf count");
    }

    function test_InitiallyUnsolved() public view {
        assertFalse(lab.isSolved(userA));
        assertFalse(lab.isSolved(userB));
        assertFalse(lab.solvedBy(userA));
    }

    // --- per-user assignment ---------------------------------------------

    function test_RequiredIndexIsDeterministicAndInRange() public view {
        uint256 first = lab.requiredIndex(userA);
        assertEq(first, lab.requiredIndex(userA), "deterministic");
        assertLt(first, lab.LEAF_COUNT(), "within range");
        assertLt(lab.requiredIndex(userB), lab.LEAF_COUNT());
    }

    function test_DifferentUsersGetDifferentAssignments() public view {
        // Leaves must differ even if two users happen to share an index.
        assertTrue(lab.leafFor(userA) != lab.leafFor(userB), "leaves differ per user");

        // Across a spread of addresses the lab must not hand everyone index 0.
        bool sawNonZero;
        for (uint256 i = 1; i <= 20; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            if (lab.requiredIndex(address(uint160(i))) != 0) {
                sawNonZero = true;
                break;
            }
        }
        assertTrue(sawNonZero, "indices must spread across the tree");
    }

    function test_LeafIsTheDoubleHashedAddress() public view {
        assertEq(lab.leafOf(userA), keccak256(bytes.concat(keccak256(abi.encode(userA)))));
        assertEq(lab.leafFor(userA), lab.leafOf(userA), "own leaf is an ordinary list entry");
    }

    // --- the fixed classroom list ----------------------------------------

    function test_PeersAreFixedDistinctAndNonZero() public view {
        for (uint256 i = 0; i < lab.PEER_COUNT(); i++) {
            address peer = lab.peerAt(i);
            assertTrue(peer != address(0), "peer must not be the zero address");
            assertEq(peer, lab.peerAt(i), "peer is deterministic");
            for (uint256 j = i + 1; j < lab.PEER_COUNT(); j++) {
                assertTrue(peer != lab.peerAt(j), "peers must be distinct");
            }
        }
    }

    function test_RevertWhen_PeerIndexOutOfRange() public {
        uint256 peerCount = lab.PEER_COUNT();
        vm.expectRevert(
            abi.encodeWithSelector(
                Q27MerkleAllowlistLab.PeerOutOfRange.selector, peerCount, peerCount
            )
        );
        lab.peerAt(peerCount);
    }

    function test_ListPlacesCallerAtRequiredIndexAndPeersElsewhere() public view {
        uint256 index = lab.requiredIndex(userA);
        address[8] memory list = lab.treeAddresses(userA);
        bytes32[8] memory leaves = lab.treeLeaves(userA);

        assertEq(list[index], userA, "caller sits at the required slot");
        assertEq(leaves[index], lab.leafFor(userA), "caller leaf matches the slot");

        uint256 peerIndex;
        for (uint256 slot = 0; slot < 8; slot++) {
            assertEq(leaves[slot], lab.leafOf(list[slot]), "every slot hashes its address");
            if (slot == index) continue;
            assertEq(list[slot], lab.peerAt(peerIndex), "peers fill remaining slots in order");
            peerIndex++;
        }
        assertEq(peerIndex, lab.PEER_COUNT(), "all seven peers are used exactly once");
    }

    function test_ListDiffersPerUser() public view {
        // Two users share the seven peers but never the same full list.
        bytes32[8] memory a = lab.treeLeaves(userA);
        bytes32[8] memory b = lab.treeLeaves(userB);

        bool differs;
        for (uint256 slot = 0; slot < 8; slot++) {
            if (a[slot] != b[slot]) {
                differs = true;
                break;
            }
        }
        assertTrue(differs, "each user rebuilds their own list");
    }

    // --- claim guards -----------------------------------------------------

    function test_RevertWhen_ClaimingWithoutCommittedRoot() public {
        // Hoisted: any call made inside the argument list would consume the
        // expectRevert before `claim` is reached.
        uint256 index = lab.requiredIndex(userA);
        bytes32[] memory proof = _proofOfLength(3);

        vm.prank(userA);
        vm.expectRevert(Q27MerkleAllowlistLab.NoCommittedRoot.selector);
        lab.claim(index, proof);
    }

    function test_RevertWhen_ProofLengthWrong() public {
        uint256 index = lab.requiredIndex(userA);
        bytes32[] memory none = _emptyProof();
        bytes32[] memory tooLong = _proofOfLength(4);

        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(0x1234)));

        vm.expectRevert(abi.encodeWithSelector(Q27MerkleAllowlistLab.BadProofLength.selector, 0, 3));
        lab.claim(index, none);

        vm.expectRevert(abi.encodeWithSelector(Q27MerkleAllowlistLab.BadProofLength.selector, 4, 3));
        lab.claim(index, tooLong);
        vm.stopPrank();
    }

    function test_RevertWhen_IndexWrong() public {
        uint256 expected = lab.requiredIndex(userA);
        uint256 wrong = (expected + 1) % lab.LEAF_COUNT();
        bytes32[] memory proof = _proofOfLength(3);

        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(0x1234)));
        vm.expectRevert(
            abi.encodeWithSelector(Q27MerkleAllowlistLab.WrongIndex.selector, wrong, expected)
        );
        lab.claim(wrong, proof);
        vm.stopPrank();
    }

    function test_RevertWhen_ProofDoesNotReachCommittedRoot() public {
        bytes32 committed = bytes32(uint256(0x1234));
        uint256 index = lab.requiredIndex(userA);
        bytes32[] memory bogus = _proofOfLength(3);
        bytes32 computed = lab.computeRoot(lab.leafFor(userA), index, bogus);

        vm.startPrank(userA);
        lab.commitRoot(committed);
        vm.expectRevert(
            abi.encodeWithSelector(Q27MerkleAllowlistLab.RootMismatch.selector, computed, committed)
        );
        lab.claim(index, bogus);
        vm.stopPrank();
    }

    // --- computeRoot is a pure helper -------------------------------------

    function test_ComputeRootRespectsDirection() public view {
        bytes32 leaf = lab.leafFor(userA);
        bytes32[] memory proof = _proofOfLength(3);

        // Index 0 (all-left) and index 7 (all-right) must not agree, or the
        // sibling ordering is not actually being enforced.
        assertTrue(
            lab.computeRoot(leaf, 0, proof) != lab.computeRoot(leaf, 7, proof),
            "direction bits must matter"
        );
    }

    // --- per-user isolation -----------------------------------------------

    function test_PerUserIsolation() public {
        vm.prank(userA);
        lab.commitRoot(bytes32(uint256(0xAAAA)));

        assertEq(lab.committedRoot(userA), bytes32(uint256(0xAAAA)));
        assertEq(lab.committedRoot(userB), bytes32(0), "userB untouched");
        assertFalse(lab.isSolved(userB));
    }

    function test_CommitRootCanBeReplacedBeforeClaiming() public {
        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(1)));
        lab.commitRoot(bytes32(uint256(2)));
        vm.stopPrank();

        assertEq(lab.committedRoot(userA), bytes32(uint256(2)));
    }

    // --- SolvableBase wiring ----------------------------------------------

    function test_RevertWhen_SolvingBeforeSolved() public {
        vm.prank(userA);
        vm.expectRevert(ISolvable.NotSolved.selector);
        lab.solve();
    }
}
