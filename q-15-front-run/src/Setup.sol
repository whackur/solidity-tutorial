// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice A "guess the secret to win the prize" game whose designer
///         thought `bytes32 private` was enough to hide the answer.
///         Anyone can read the secret directly from chain storage via
///         `eth_getStorageAt` and claim the prize before the legitimate
///         owner — the canonical "secret on-chain" + front-running shape.
///
///         Storage layout:
///           slot 0  ─ address owner            (right-aligned in 32 bytes)
///           slot 1  ─ bytes32 _secret          (this is what you read)
///           slot 2  ─ address winner           (right-aligned in 32 bytes)
contract FrontRunChallenge {
    address public owner;
    bytes32 private _secret;
    address public winner;

    event Claimed(address indexed winner);

    constructor(address o, bytes32 s) payable {
        owner = o;
        _secret = s;
    }

    function claim(bytes32 guess) external {
        require(winner == address(0), "already claimed");
        require(guess == _secret, "wrong");
        winner = msg.sender;
        // Forward the entire prize to whoever guessed correctly.
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "send failed");
        emit Claimed(msg.sender);
    }

    /// @notice Documents where the secret lives. Off-chain tooling can
    ///         read it with `eth_getStorageAt(address, secretSlot())`.
    function secretSlot() external pure returns (uint256) {
        return 1;
    }

    receive() external payable {}
}

/// @notice Multi-tenant lab. `createInstance()` deploys a per-user
///         `FrontRunChallenge` seeded with `PRIZE` ETH and a fresh
///         secret derived from caller + tx context.
contract FrontRunLab is SolvableBase {
    uint256 public constant PRIZE = 1 ether;

    mapping(address => FrontRunChallenge) private _challenges;
    uint256 private _nonce;

    event InstanceCreated(address indexed user, address challenge);

    receive() external payable {}

    function createInstance() external returns (address challenge) {
        require(address(_challenges[msg.sender]) == address(0), "already created");
        require(address(this).balance >= PRIZE, "lab underfunded");

        _nonce += 1;
        bytes32 secret = keccak256(abi.encode(msg.sender, block.timestamp, block.prevrandao, _nonce));
        FrontRunChallenge c = new FrontRunChallenge{value: PRIZE}(msg.sender, secret);

        _challenges[msg.sender] = c;
        emit InstanceCreated(msg.sender, address(c));
        return address(c);
    }

    function challengeOf(address user) external view returns (FrontRunChallenge) {
        return _challenges[user];
    }

    function isSolved(address user) public view override returns (bool) {
        FrontRunChallenge c = _challenges[user];
        if (address(c) == address(0)) return false;
        return c.winner() == user;
    }
}
