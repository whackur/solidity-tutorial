// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MerkleAllowlist
 * @notice An allowlist gate that stores a single 32-byte root instead of one
 *         storage slot per allowed address.
 *
 *         The operator builds a merkle tree over the allowed addresses
 *         off-chain, publishes the tree, and commits only the root here.
 *         An address proves membership once with `register`, after which
 *         access is a plain mapping read.
 *
 *         Leaf format: keccak256(bytes.concat(keccak256(abi.encode(account)))).
 *         The double hash is the OpenZeppelin convention for leaves whose
 *         preimage is attacker-controlled — it makes it impossible to pass a
 *         64-byte internal node off as a leaf (second-preimage attack).
 *
 *         Proofs use sorted-pair hashing: at each level the two children are
 *         hashed in ascending byte order, so a proof carries no direction
 *         bits. That halves the calldata a caller must supply and is what
 *         `MerkleProof.verify` implements. The tradeoff is that a sorted tree
 *         cannot express leaf position, so it cannot be used where the index
 *         itself is meaningful — see MerkleDistributor, which commits the
 *         index inside the leaf for exactly that reason.
 */
contract MerkleAllowlist is Ownable {
    /// @notice Root of the current allowlist tree. Zero disables registration.
    bytes32 public allowlistRoot;

    mapping(address account => bool) private _registered;

    event AllowlistRootUpdated(bytes32 indexed previousRoot, bytes32 indexed newRoot);
    event Registered(address indexed account);
    event Revoked(address indexed account);

    error RootNotSet();
    error InvalidProof();
    error AlreadyRegistered();
    error NotRegistered();

    constructor(bytes32 initialRoot, address initialOwner) Ownable(initialOwner) {
        allowlistRoot = initialRoot;
        emit AllowlistRootUpdated(bytes32(0), initialRoot);
    }

    /**
     * @notice Replace the allowlist root.
     * @dev Rotating the root only changes who can register *from now on*. It
     *      does NOT revoke anyone who already registered under the old root —
     *      their `_registered` slot is untouched. That asymmetry is the main
     *      trap of this pattern: operators assume "new root = new allowlist"
     *      and are surprised that removed addresses still transfer.
     *
     *      Removal is therefore an explicit, per-address operation. See
     *      `revoke`. If you need removal to be cheap and bulk, this pattern is
     *      the wrong one — store the list.
     */
    function setAllowlistRoot(bytes32 newRoot) external onlyOwner {
        bytes32 previous = allowlistRoot;
        allowlistRoot = newRoot;
        emit AllowlistRootUpdated(previous, newRoot);
    }

    /// @notice Prove that `msg.sender` is in the committed tree.
    function register(bytes32[] calldata proof) external {
        if (allowlistRoot == bytes32(0)) revert RootNotSet();
        if (_registered[msg.sender]) revert AlreadyRegistered();
        if (!MerkleProof.verify(proof, allowlistRoot, leafOf(msg.sender))) {
            revert InvalidProof();
        }
        _registered[msg.sender] = true;
        emit Registered(msg.sender);
    }

    /// @notice Remove an address that was registered under this or an older root.
    function revoke(address account) external onlyOwner {
        if (!_registered[account]) revert NotRegistered();
        _registered[account] = false;
        emit Revoked(account);
    }

    function isAllowed(address account) public view returns (bool) {
        return _registered[account];
    }

    /// @notice Leaf hash for an account. Exposed so off-chain tooling and the
    ///         tests build the tree exactly the way the contract reads it.
    function leafOf(address account) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }
}
