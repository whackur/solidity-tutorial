// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Beginner ecrecover lab. The lab publishes N candidate signed
///         messages (a `messageHash`, plus `(v, r, s)`). Exactly ONE of
///         them was signed by `trustedSigner`. The student reads each
///         candidate, runs `ecrecover` off-chain (wallet, web UI, or a
///         scripting environment), identifies which index recovers to
///         `trustedSigner`, and submits that index.
///
///         No EIP-191 prefix and no EIP-712 domain here — the point is
///         to see the *raw* `ecrecover(hash, v, r, s) -> signer` primitive
///         on its own before q-07 layers the eth-sign prefix and q-08
///         adds typed-data domain separation.
contract EcrecoverBasicLab is SolvableBase {
    struct Candidate {
        bytes32 messageHash; // keccak256(message), no eth-sign wrapping
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    address public immutable trustedSigner;
    uint256 public immutable candidateCount;

    mapping(uint256 => Candidate) private _candidates;
    mapping(address => bool) private _solved;
    mapping(address => uint256) private _submittedIndex;

    event Submitted(address indexed user, uint256 index, address recovered);

    error WrongSigner(address recovered);
    error InvalidIndex();

    constructor(address signer, Candidate[] memory cands) {
        require(signer != address(0), "signer=0");
        require(cands.length > 0, "no candidates");
        trustedSigner = signer;
        candidateCount = cands.length;
        for (uint256 i = 0; i < cands.length; i++) {
            _candidates[i] = cands[i];
        }
    }

    /// @notice Read a candidate so a student or web UI can run ecrecover
    ///         off-chain against each one.
    function candidate(uint256 i) external view returns (bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) {
        require(i < candidateCount, "out of range");
        Candidate memory c = _candidates[i];
        return (c.messageHash, c.v, c.r, c.s);
    }

    /// @notice Submit the index of the candidate you believe was signed
    ///         by `trustedSigner`. The lab runs `ecrecover` on-chain and
    ///         marks the user solved iff it matches.
    function submit(uint256 index) external {
        if (index >= candidateCount) revert InvalidIndex();
        Candidate memory c = _candidates[index];
        address recovered = ecrecover(c.messageHash, c.v, c.r, c.s);
        if (recovered != trustedSigner) revert WrongSigner(recovered);
        _solved[msg.sender] = true;
        _submittedIndex[msg.sender] = index;
        emit Submitted(msg.sender, index, recovered);
    }

    function submittedIndex(address user) external view returns (uint256) {
        return _submittedIndex[user];
    }

    function isSolved(address user) public view override returns (bool) {
        return _solved[user];
    }
}
