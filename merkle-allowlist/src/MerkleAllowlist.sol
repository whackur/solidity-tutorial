// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title MerkleAllowlist
 * @notice A per-user Merkle proof gate with self-managed roots.
 *
 *         Each learner commits their own root. The leaf includes the learner
 *         address and that learner's registration counter, so a new root can
 *         be used for another successful registration without sharing state
 *         with any other learner.
 *
 *         Leaves are double-hashed with `abi.encode(account, counter)`. Proofs
 *         are direction-aware: bit `i` of the supplied index decides whether
 *         the running node is the left or right child at level `i`. This is
 *         the same path arithmetic used by the q-27 Merkle lab.
 */
contract MerkleAllowlist {
    /// @notice The fixed classroom tree shape used by the Q-27 exercise.
    uint256 public constant LEAF_COUNT = 8;
    uint256 public constant PROOF_LENGTH = 3;

    /// @notice The root committed by each account for its next registration.
    mapping(address account => bytes32) public committedRoot;

    /// @notice Number of successful registrations made by each account.
    mapping(address account => uint256) public counter;

    mapping(address account => bool) private _registered;

    event RootCommitted(address indexed account, bytes32 indexed root, uint256 counter);
    event Registered(address indexed account, uint256 indexed index, uint256 counter);
    event Revoked(address indexed account, uint256 counter);

    error RootNotSet();
    error InvalidProof();
    error BadProofLength(uint256 given, uint256 expected);
    error IndexOutOfRange(uint256 given, uint256 leafCount);
    error NotRegistered();

    /// @notice Commit or replace the root for the caller's next registration.
    /// @dev A zero root is retained as an explicit unset state and cannot be
    ///      used to register.
    function commitRoot(bytes32 root) external {
        committedRoot[msg.sender] = root;
        emit RootCommitted(msg.sender, root, counter[msg.sender]);
    }

    /**
     * @notice Prove the caller's current-counter leaf is at `index`.
     * @dev The caller's counter is read before any state update. Reverted
     *      proofs therefore leave both the counter and registration unchanged.
     */
    function register(uint256 index, bytes32[] calldata proof) external {
        bytes32 root = committedRoot[msg.sender];
        if (root == bytes32(0)) revert RootNotSet();
        if (proof.length != PROOF_LENGTH) revert BadProofLength(proof.length, PROOF_LENGTH);
        if (index >= LEAF_COUNT) revert IndexOutOfRange(index, LEAF_COUNT);

        bytes32 computed = computeRoot(leafFor(msg.sender, counter[msg.sender]), index, proof);
        if (computed != root) revert InvalidProof();

        uint256 nextCounter = counter[msg.sender] + 1;
        counter[msg.sender] = nextCounter;
        _registered[msg.sender] = true;
        emit Registered(msg.sender, index, nextCounter);
    }

    /// @notice Revoke only the caller's own access. The registration counter
    ///         intentionally remains unchanged so it cannot be replayed.
    function revoke() external {
        if (!_registered[msg.sender]) revert NotRegistered();
        _registered[msg.sender] = false;
        emit Revoked(msg.sender, counter[msg.sender]);
    }

    /// @notice Whether an account currently has access to the restricted token.
    function isAllowed(address account) public view returns (bool) {
        return _registered[account];
    }

    /// @notice Double-hashed leaf used by `register`.
    function leafFor(address account, uint256 registrationCounter) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, registrationCounter))));
    }

    /**
     * @notice Walk a leaf up to a root using index bits for direction.
     * @dev Bit `i` of `index` says where the running node sits at level `i`:
     *      zero means left, one means right. Pair encoding matches q-27.
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
}
