// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Storage-layout challenge. The contract holds two secret values:
///
///         - `secretA` is declared as a normal private field. Storage slots
///           are assigned in declaration order across the full inheritance
///           chain, so `secretA` lives at the slot immediately after every
///           slot SolvableBase already occupies.
///
///         - `secretB` is written to an explicit slot derived from
///           keccak256("q23.secret.b"), the same idiom EIP-1967 uses to keep
///           proxy bookkeeping out of the way of the implementation's
///           sequential layout. The slot constant is `public`, so the
///           location is part of the published ABI.
///
///         `private` only hides the *Solidity accessor*. Storage itself is
///         public — anyone with the contract address can call
///         `eth_getStorageAt(addr, slot)` and read the raw 32-byte word.
///         Solving this challenge means doing exactly that for both slots
///         and then proving you can read them by calling submit().
contract Vault is SolvableBase {
    // SolvableBase declares `solvedBy` (mapping) first, which occupies
    // slot 0 (the mapping head — the per-key data lives at keccak slots,
    // not at slot 0 itself). The next freshly declared variable therefore
    // lands at slot 1.
    bytes32 private secretA;

    /// @notice Storage slot that holds secretB. Computed at compile time so
    ///         the constant lives in code, not in storage. Anyone can read
    ///         the value with `eth_getStorageAt(vault, SLOT_B)`.
    bytes32 public constant SLOT_B = keccak256("q23.secret.b");

    mapping(address => bool) public submitted;

    event Submitted(address indexed user);
    error WrongSecretA(bytes32 submitted);
    error WrongSecretB(bytes32 submitted);

    constructor(bytes32 a, bytes32 b) {
        secretA = a;
        bytes32 slot = SLOT_B;
        assembly {
            sstore(slot, b)
        }
    }

    /// @notice Prove you can read both storage slots from off-chain.
    ///         Reverts with WrongSecretA / WrongSecretB on mismatch, so the
    ///         revert reason tells you which read failed.
    function submit(bytes32 a, bytes32 b) external {
        if (a != secretA) revert WrongSecretA(a);
        bytes32 storedB;
        bytes32 slot = SLOT_B;
        assembly {
            storedB := sload(slot)
        }
        if (b != storedB) revert WrongSecretB(b);
        submitted[msg.sender] = true;
        emit Submitted(msg.sender);
    }

    function isSolved(address user) public view override returns (bool) {
        return submitted[user];
    }
}
