// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/**
 * @notice Beginner merkle-proof lab. The student builds a merkle tree by hand
 *         and proves that their own leaf sits at a specific position in it.
 *
 *         Each user is assigned a leaf index derived from their address.
 *         There are only eight positions, so different users may share a path
 *         shape, but their leaves still differ and a neighbour's proof cannot
 *         be copied unchanged. Index 0 is not a safe guess.
 *
 *         Verification here is index/direction based, NOT sorted-pair based.
 *         At each level the current position bit decides whether the running
 *         node is the left or the right child. Sorted-pair hashing (what
 *         OpenZeppelin's `MerkleProof.verify` does) would accept a path whose
 *         sibling order is wrong, and getting that order right is the entire
 *         point of the exercise.
 *
 *         The other seven leaves of the tree are never inspected. A student
 *         may fill them with arbitrary values — this lab checks that they can
 *         compute a path, not that they belong to any real allowlist.
 */
contract Q27MerkleAllowlistLab is SolvableBase {
    /// @notice A balanced tree of 8 leaves has depth 3.
    uint256 public constant LEAF_COUNT = 8;
    uint256 public constant PROOF_LENGTH = 3;

    /// @notice The only allocation this lab accepts.
    uint256 public constant REQUIRED_AMOUNT = 1000 ether;

    mapping(address user => bytes32) public committedRoot;
    mapping(address user => bool) private _claimed;

    event RootCommitted(address indexed user, bytes32 root);
    event Claimed(address indexed user, uint256 index, uint256 amount);

    error BadProofLength(uint256 given, uint256 expected);
    error WrongIndex(uint256 given, uint256 expected);
    error WrongAmount(uint256 given, uint256 expected);
    error NoCommittedRoot();
    error AlreadyClaimed();
    error RootMismatch(bytes32 computed, bytes32 committed);

    /// @notice The leaf position this user must prove. Different per address.
    function requiredIndex(address user) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(user))) % LEAF_COUNT;
    }

    /// @notice The exact leaf the user must place at `requiredIndex(user)`.
    ///         Exposed so a UI can display it — building the surrounding tree
    ///         and the path is still the student's job.
    function leafFor(address user) public pure returns (bytes32) {
        return keccak256(abi.encode(user, requiredIndex(user), REQUIRED_AMOUNT));
    }

    /// @notice Commit the root of the 8-leaf tree you built. May be replaced
    ///         freely until you claim.
    function commitRoot(bytes32 root) external {
        if (_claimed[msg.sender]) revert AlreadyClaimed();
        committedRoot[msg.sender] = root;
        emit RootCommitted(msg.sender, root);
    }

    /// @notice Prove that `leafFor(msg.sender)` sits at `index` in the tree
    ///         whose root you committed.
    function claim(uint256 index, uint256 amount, bytes32[] calldata proof) external {
        if (_claimed[msg.sender]) revert AlreadyClaimed();

        bytes32 root = committedRoot[msg.sender];
        if (root == bytes32(0)) revert NoCommittedRoot();

        if (proof.length != PROOF_LENGTH) revert BadProofLength(proof.length, PROOF_LENGTH);

        uint256 expectedIndex = requiredIndex(msg.sender);
        if (index != expectedIndex) revert WrongIndex(index, expectedIndex);
        if (amount != REQUIRED_AMOUNT) revert WrongAmount(amount, REQUIRED_AMOUNT);

        bytes32 computed = computeRoot(leafFor(msg.sender), index, proof);
        if (computed != root) revert RootMismatch(computed, root);

        _claimed[msg.sender] = true;
        emit Claimed(msg.sender, index, amount);
    }

    /**
     * @notice Walk a leaf up to a root using index bits for direction.
     * @dev Bit `i` of `index` says where the running node sits at level `i`:
     *      0 means it is the left child and the proof element is on the right,
     *      1 means it is the right child and the proof element is on the left.
     *      Public so a student can check their path arithmetic without sending
     *      a transaction.
     */
    function computeRoot(bytes32 leaf, uint256 index, bytes32[] calldata proof)
        public
        pure
        returns (bytes32)
    {
        bytes32 node = leaf;
        uint256 position = index;
        for (uint256 i = 0; i < proof.length; i++) {
            node = position & 1 == 0
                ? keccak256(abi.encode(node, proof[i]))
                : keccak256(abi.encode(proof[i], node));
            position >>= 1;
        }
        return node;
    }

    function isSolved(address user) public view override returns (bool) {
        return _claimed[user];
    }
}
