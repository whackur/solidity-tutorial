// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title MerkleDistributor
 * @notice Pull-based distribution: the operator commits a root over
 *         (index, account, amount) leaves, funds this contract, and each
 *         recipient claims their own allocation.
 *
 *         Pull matters when the token being distributed is allowed to refuse
 *         a transfer. A push loop that iterates recipients inside one call
 *         reverts as a whole the moment a single recipient is not allowed to
 *         receive — so one blocked address freezes the entire distribution.
 *         With pull, that address simply fails its own claim and everyone
 *         else is unaffected; the unclaimed amount stays visible on-chain
 *         instead of being silently skipped.
 *
 *         The index lives inside the leaf because claim tracking needs a
 *         stable, compact identifier. That is also why this contract cannot
 *         use the sorted-pair trick to infer position — position is data, not
 *         a hashing detail.
 */
contract MerkleDistributor {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;

    /// @dev One bit per index, packed 256 to a word. A `mapping(uint256 => bool)`
    ///      burns a whole 20k-gas cold slot per claim; the bitmap amortises that
    ///      across 256 claims, and consecutive claimers in the same word pay the
    ///      5k warm-write price instead.
    mapping(uint256 word => uint256 bits) private _claimedBitMap;

    event Claimed(uint256 indexed index, address indexed account, uint256 amount);

    error AlreadyClaimed();
    error InvalidProof();

    constructor(IERC20 token_, bytes32 merkleRoot_) {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 word = index / 256;
        uint256 bit = index % 256;
        return _claimedBitMap[word] & (uint256(1) << bit) != 0;
    }

    /**
     * @notice Claim the allocation committed at `index`.
     * @dev Permissionless by design. Anyone may submit anyone else's proof and
     *      the tokens still go to `account`, never to `msg.sender`. That lets an
     *      operator batch-submit claims on behalf of recipients without ever
     *      being able to redirect the funds.
     */
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata proof)
        external
    {
        if (isClaimed(index)) revert AlreadyClaimed();

        bytes32 leaf = leafOf(index, account, amount);
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        _setClaimed(index);
        token.safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    /// @notice Leaf hash for an allocation. Double-hashed for the same
    ///         second-preimage reason as MerkleAllowlist.
    function leafOf(uint256 index, address account, uint256 amount) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
    }

    function _setClaimed(uint256 index) private {
        uint256 word = index / 256;
        uint256 bit = index % 256;
        _claimedBitMap[word] |= (uint256(1) << bit);
    }
}
