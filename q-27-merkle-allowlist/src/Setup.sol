// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/**
 * @notice Beginner merkle-proof lab. The student rebuilds an allowlist of
 *         eight addresses and proves that their own address sits at its
 *         assigned position in that list.
 *
 *         The list is not arbitrary. Seven fixed classroom peer addresses are
 *         derived on-chain by `peerAt`, and the caller occupies the slot given
 *         by `requiredIndex(caller)`. `treeLeaves(caller)` returns the whole
 *         list of leaves in slot order, so nothing about the list is guesswork:
 *         the exercise is to hash the list up to a root and to get the path
 *         directions right.
 *
 *         Leaves are double-hashed over the address alone, the same formula
 *         the merkle-allowlist tutorial uses:
 *         `keccak256(bytes.concat(keccak256(abi.encode(account))))`.
 *
 *         Verification is index/direction based, NOT sorted-pair based. At each
 *         level the current position bit decides whether the running node is
 *         the left or the right child. Sorted-pair hashing (what OpenZeppelin's
 *         `MerkleProof.verify` does) would accept a path whose sibling order is
 *         wrong, and getting that order right is the point of the exercise.
 *
 *         Index 0 is not a safe guess: the required slot is derived from the
 *         caller address, so a neighbour's index and path cannot be copied.
 */
contract Q27MerkleAllowlistLab is SolvableBase {
    /// @notice A balanced tree of 8 leaves has depth 3.
    uint256 public constant LEAF_COUNT = 8;
    uint256 public constant PROOF_LENGTH = 3;

    /// @notice Number of fixed classroom addresses that fill the other slots.
    uint256 public constant PEER_COUNT = 7;

    mapping(address user => bytes32) public committedRoot;
    mapping(address user => bool) private _claimed;

    event RootCommitted(address indexed user, bytes32 root);
    event Claimed(address indexed user, uint256 index);

    error BadProofLength(uint256 given, uint256 expected);
    error WrongIndex(uint256 given, uint256 expected);
    error NoCommittedRoot();
    error AlreadyClaimed();
    error RootMismatch(bytes32 computed, bytes32 committed);
    error PeerOutOfRange(uint256 given, uint256 peerCount);

    /// @notice The slot this caller must prove. Derived from the address.
    function requiredIndex(address user) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(user))) % LEAF_COUNT;
    }

    /// @notice One of the seven fixed classroom addresses that fill the list.
    /// @dev Derived, not stored: neutral educational values with no owner and
    ///      no private key in play.
    function peerAt(uint256 peerIndex) public pure returns (address) {
        if (peerIndex >= PEER_COUNT) revert PeerOutOfRange(peerIndex, PEER_COUNT);
        return
            address(
                uint160(uint256(keccak256(abi.encode("q-27-merkle-allowlist:peer", peerIndex))))
            );
    }

    /// @notice Leaf hash of a single allowlist entry.
    function leafOf(address account) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    /// @notice The exact leaf the caller must place at `requiredIndex(user)`.
    function leafFor(address user) public pure returns (bytes32) {
        return leafOf(user);
    }

    /// @notice The address occupying each slot of this user's list.
    /// @dev The caller sits at `requiredIndex(user)`; the seven peers fill the
    ///      remaining slots in ascending slot order.
    function treeAddresses(address user) public pure returns (address[LEAF_COUNT] memory list) {
        uint256 index = requiredIndex(user);
        uint256 peerIndex;
        for (uint256 slot = 0; slot < LEAF_COUNT; slot++) {
            if (slot == index) {
                list[slot] = user;
            } else {
                list[slot] = peerAt(peerIndex);
                peerIndex++;
            }
        }
    }

    /// @notice The leaves of this user's list, in slot order.
    function treeLeaves(address user) public pure returns (bytes32[LEAF_COUNT] memory leaves) {
        address[LEAF_COUNT] memory list = treeAddresses(user);
        for (uint256 slot = 0; slot < LEAF_COUNT; slot++) {
            leaves[slot] = leafOf(list[slot]);
        }
    }

    /// @notice Commit the root of the list you rebuilt. May be replaced freely
    ///         until you claim.
    function commitRoot(bytes32 root) external {
        if (_claimed[msg.sender]) revert AlreadyClaimed();
        committedRoot[msg.sender] = root;
        emit RootCommitted(msg.sender, root);
    }

    /// @notice Prove that `leafFor(msg.sender)` sits at `index` in the list
    ///         whose root you committed.
    function claim(uint256 index, bytes32[] calldata proof) external {
        if (_claimed[msg.sender]) revert AlreadyClaimed();

        bytes32 root = committedRoot[msg.sender];
        if (root == bytes32(0)) revert NoCommittedRoot();

        if (proof.length != PROOF_LENGTH) revert BadProofLength(proof.length, PROOF_LENGTH);

        uint256 expectedIndex = requiredIndex(msg.sender);
        if (index != expectedIndex) revert WrongIndex(index, expectedIndex);

        bytes32 computed = computeRoot(leafFor(msg.sender), index, proof);
        if (computed != root) revert RootMismatch(computed, root);

        _claimed[msg.sender] = true;
        emit Claimed(msg.sender, index);
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
