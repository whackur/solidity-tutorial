// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @notice Test-only merkle tree builder using sorted-pair hashing, matching
 *         what OpenZeppelin's `MerkleProof.verify` expects.
 *
 *         Levels are built bottom-up. An odd node at the end of a level is
 *         promoted unchanged to the next level rather than being hashed with
 *         itself, so it contributes no proof element at that step.
 *
 *         This lives in `test/` on purpose — production trees are built
 *         off-chain, and nothing here is deployed.
 */
library MerkleTreeLib {
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    /// @dev Rebuilds every level and returns the root.
    function root(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "empty tree");
        bytes32[] memory level = leaves;
        while (level.length > 1) {
            level = _nextLevel(level);
        }
        return level[0];
    }

    /// @dev Collects the sibling at each level on the path from `index` up.
    function proof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        require(index < leaves.length, "index out of range");

        bytes32[] memory buffer = new bytes32[](_depth(leaves.length));
        uint256 count;

        bytes32[] memory level = leaves;
        uint256 pos = index;
        while (level.length > 1) {
            uint256 sibling = pos ^ 1;
            if (sibling < level.length) {
                buffer[count++] = level[sibling];
            }
            level = _nextLevel(level);
            pos /= 2;
        }

        bytes32[] memory out = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            out[i] = buffer[i];
        }
        return out;
    }

    function _nextLevel(bytes32[] memory level) private pure returns (bytes32[] memory) {
        uint256 width = (level.length + 1) / 2;
        bytes32[] memory next = new bytes32[](width);
        for (uint256 i = 0; i < width; i++) {
            uint256 left = i * 2;
            uint256 right = left + 1;
            next[i] = right < level.length ? hashPair(level[left], level[right]) : level[left];
        }
        return next;
    }

    function _depth(uint256 leafCount) private pure returns (uint256 d) {
        uint256 width = leafCount;
        while (width > 1) {
            width = (width + 1) / 2;
            d++;
        }
    }
}
