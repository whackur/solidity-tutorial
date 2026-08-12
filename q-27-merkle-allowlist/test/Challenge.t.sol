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
        assertEq(lab.REQUIRED_AMOUNT(), 1000 ether);
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

    // --- claim guards -----------------------------------------------------

    function test_RevertWhen_ClaimingWithoutCommittedRoot() public {
        // Hoisted: any call made inside the argument list would consume the
        // expectRevert before `claim` is reached.
        uint256 index = lab.requiredIndex(userA);
        uint256 amount = lab.REQUIRED_AMOUNT();
        bytes32[] memory proof = _proofOfLength(3);

        vm.prank(userA);
        vm.expectRevert(Q27MerkleAllowlistLab.NoCommittedRoot.selector);
        lab.claim(index, amount, proof);
    }

    function test_RevertWhen_ProofLengthWrong() public {
        uint256 index = lab.requiredIndex(userA);
        uint256 amount = lab.REQUIRED_AMOUNT();
        bytes32[] memory none = _emptyProof();
        bytes32[] memory tooLong = _proofOfLength(4);

        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(0x1234)));

        vm.expectRevert(abi.encodeWithSelector(Q27MerkleAllowlistLab.BadProofLength.selector, 0, 3));
        lab.claim(index, amount, none);

        vm.expectRevert(abi.encodeWithSelector(Q27MerkleAllowlistLab.BadProofLength.selector, 4, 3));
        lab.claim(index, amount, tooLong);
        vm.stopPrank();
    }

    function test_RevertWhen_IndexWrong() public {
        uint256 expected = lab.requiredIndex(userA);
        uint256 wrong = (expected + 1) % lab.LEAF_COUNT();
        uint256 amount = lab.REQUIRED_AMOUNT();
        bytes32[] memory proof = _proofOfLength(3);

        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(0x1234)));
        vm.expectRevert(
            abi.encodeWithSelector(Q27MerkleAllowlistLab.WrongIndex.selector, wrong, expected)
        );
        lab.claim(wrong, amount, proof);
        vm.stopPrank();
    }

    function test_RevertWhen_AmountWrong() public {
        uint256 index = lab.requiredIndex(userA);
        uint256 required = lab.REQUIRED_AMOUNT();
        bytes32[] memory proof = _proofOfLength(3);

        vm.startPrank(userA);
        lab.commitRoot(bytes32(uint256(0x1234)));
        vm.expectRevert(
            abi.encodeWithSelector(Q27MerkleAllowlistLab.WrongAmount.selector, 1 ether, required)
        );
        lab.claim(index, 1 ether, proof);
        vm.stopPrank();
    }

    function test_RevertWhen_ProofDoesNotReachCommittedRoot() public {
        bytes32 committed = bytes32(uint256(0x1234));
        uint256 index = lab.requiredIndex(userA);
        uint256 amount = lab.REQUIRED_AMOUNT();
        bytes32[] memory bogus = _proofOfLength(3);
        bytes32 computed = lab.computeRoot(lab.leafFor(userA), index, bogus);

        vm.startPrank(userA);
        lab.commitRoot(committed);
        vm.expectRevert(
            abi.encodeWithSelector(Q27MerkleAllowlistLab.RootMismatch.selector, computed, committed)
        );
        lab.claim(index, amount, bogus);
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
