// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Multi-tenant EIP-191 signature lab. A single instance is shared.
///         Each user proves possession of their EOA private key by signing
///         a per-user 32-byte challenge using eth_sign, and a free-form
///         message using personal_sign. Both must verify against the
///         caller's own address.
///
///         Progress is keyed by msg.sender (= recovered signer).
contract EthSignChallenge is SolvableBase {
    using MessageHashUtils for bytes32;
    using MessageHashUtils for bytes;

    mapping(address => bytes32) public challengeOf;
    mapping(address => bool) public solvedEthSign;
    mapping(address => bool) public solvedPersonalSign;

    event ChallengeIssued(address indexed user, bytes32 challenge);
    event EthSignVerified(address indexed user);
    event PersonalSignVerified(address indexed user);

    /// @notice Mints a fresh per-user challenge hash. Each call rerolls it.
    function startChallenge() external returns (bytes32 challenge) {
        challenge = keccak256(abi.encode(msg.sender, block.timestamp, block.prevrandao));
        challengeOf[msg.sender] = challenge;
        emit ChallengeIssued(msg.sender, challenge);
    }

    /// @notice Submit an EIP-191 eth_sign-style signature over your per-user
    ///         32-byte challengeOf[you]. Wallet UIs (MetaMask `personal_sign`)
    ///         already prepend the EIP-191 prefix when signing a hex string.
    function submitEthSign(bytes calldata signature) external {
        bytes32 ch = challengeOf[msg.sender];
        require(ch != bytes32(0), "no challenge - call startChallenge first");

        bytes32 digest = ch.toEthSignedMessageHash();
        address recovered = ECDSA.recover(digest, signature);
        require(recovered == msg.sender, "signature must be from msg.sender");

        solvedEthSign[msg.sender] = true;
        emit EthSignVerified(msg.sender);
    }

    /// @notice Submit an EIP-191 personal_sign-style signature over an
    ///         arbitrary-length byte message. The contract prepends the
    ///         "\x19Ethereum Signed Message:\n<len>" prefix.
    function submitPersonalSign(bytes memory message, bytes calldata signature) external {
        bytes32 digest = message.toEthSignedMessageHash();
        address recovered = ECDSA.recover(digest, signature);
        require(recovered == msg.sender, "signature must be from msg.sender");

        solvedPersonalSign[msg.sender] = true;
        emit PersonalSignVerified(msg.sender);
    }

    function isSolved(address user) public view override returns (bool) {
        return solvedEthSign[user] && solvedPersonalSign[user];
    }
}
