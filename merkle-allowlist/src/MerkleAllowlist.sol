// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title MerkleAllowlist
 * @notice A Merkle proof gate over a list of addresses, with self-managed roots.
 *
 *         The tree is built off-chain over the addresses that should be
 *         allowed. Only the root is committed on-chain, and each address then
 *         proves its own membership once.
 *
 *         There is no owner. Every caller commits the root of the list it was
 *         built into, so a group can share one list: each member commits the
 *         same root and registers with its own index and path. Nothing is
 *         keyed globally, so one member's transaction cannot move another
 *         member's state.
 *
 *         Leaves are double-hashed over the address alone:
 *         `keccak256(bytes.concat(keccak256(abi.encode(account))))`. The outer
 *         hash follows the OpenZeppelin convention for attacker-controlled
 *         preimages: it makes it impossible to pass a 64-byte internal node
 *         off as a leaf.
 *
 *         Proofs are direction-aware: bit `i` of the supplied index decides
 *         whether the running node is the left or the right child at level
 *         `i`. Sorted-pair hashing would accept a path whose sibling order is
 *         wrong, and that order is part of what this package teaches. The same
 *         path arithmetic is used by the q-27 Merkle lab.
 *
 *         Registration is not a one-way door, but rotating a root is also not
 *         a removal. `commitRoot` only changes what the *next* registration is
 *         checked against; an address that already registered keeps access
 *         until it calls `revoke`. That asymmetry is the main trap of the
 *         pattern: removal is a per-address operation, so if removal has to be
 *         cheap and in bulk, store the list instead of a root.
 */
contract MerkleAllowlist {
    /// @notice The fixed classroom tree shape shared with the q-27 lab.
    uint256 public constant LEAF_COUNT = 8;
    uint256 public constant PROOF_LENGTH = 3;

    /// @notice The root each account committed for its next registration.
    mapping(address account => bytes32) public committedRoot;

    mapping(address account => bool) private _registered;

    event RootCommitted(address indexed account, bytes32 indexed root);
    event Registered(address indexed account, uint256 indexed index);
    event Revoked(address indexed account);

    error RootNotSet();
    error InvalidProof();
    error BadProofLength(uint256 given, uint256 expected);
    error IndexOutOfRange(uint256 given, uint256 leafCount);
    error AlreadyRegistered();
    error NotRegistered();

    /// @notice Commit or replace the root of the list the caller belongs to.
    /// @dev A zero root is retained as an explicit unset state and cannot be
    ///      used to register. Committing does not grant or remove access.
    function commitRoot(bytes32 root) external {
        committedRoot[msg.sender] = root;
        emit RootCommitted(msg.sender, root);
    }

    /**
     * @notice Prove that the caller's leaf sits at `index` of the committed list.
     * @dev Reverted proofs change nothing, so a failed attempt can be retried
     *      with a corrected index or path. An address that is already
     *      registered must `revoke` first: re-registering would be a no-op and
     *      hides which call actually granted access.
     */
    function register(uint256 index, bytes32[] calldata proof) external {
        if (_registered[msg.sender]) revert AlreadyRegistered();

        bytes32 root = committedRoot[msg.sender];
        if (root == bytes32(0)) revert RootNotSet();
        if (proof.length != PROOF_LENGTH) revert BadProofLength(proof.length, PROOF_LENGTH);
        if (index >= LEAF_COUNT) revert IndexOutOfRange(index, LEAF_COUNT);

        bytes32 computed = computeRoot(leafFor(msg.sender), index, proof);
        if (computed != root) revert InvalidProof();

        _registered[msg.sender] = true;
        emit Registered(msg.sender, index);
    }

    /// @notice Revoke only the caller's own access.
    /// @dev The committed root is left in place, so the same list and the same
    ///      path can be used to register again. Nobody can revoke anybody else.
    function revoke() external {
        if (!_registered[msg.sender]) revert NotRegistered();
        _registered[msg.sender] = false;
        emit Revoked(msg.sender);
    }

    /// @notice Whether an account currently has access to the restricted token.
    function isAllowed(address account) public view returns (bool) {
        return _registered[account];
    }

    /// @notice Double-hashed leaf for an address. Exposed so off-chain tooling
    ///         builds the list exactly the way `register` reads it.
    function leafFor(address account) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    /**
     * @notice Walk a leaf up to a root using index bits for direction.
     * @dev Bit `i` of `index` says where the running node sits at level `i`:
     *      zero means left and the proof element is on the right, one means
     *      right and the proof element is on the left. Public so a caller can
     *      check its path arithmetic without sending a transaction.
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
