// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {EventsAndErrors} from "./Setup.sol";

contract Solution {
    /// @notice Return the canonical 4-byte selectors for the three error families.
    function knownSelectors()
        external
        pure
        returns (bytes4 errorStringSel, bytes4 panicSel, bytes4 customSel)
    {
        // TODO: compute each with keccak256(signature)[:4].
        //       Hint: bytes4(keccak256("Error(string)"))  → 0x08c379a0
        //             bytes4(keccak256("Panic(uint256)")) → 0x4e487b71
        //             custom: bytes4(keccak256("InsufficientBalance(uint256,uint256)"))
        revert("Solution.knownSelectors: not implemented");
    }

    /// @notice Trigger one of the three revert variants, catch it, and classify:
    ///         0 = Error(string), 1 = Panic(uint256), 2 = custom error, 3 = other
    function classify(EventsAndErrors e, uint8 kind) external returns (uint8 label) {
        // TODO: branch on `kind`, call the matching function, classify the revert.
        //       Hint: `try ... catch Error(string memory) { ... }`
        //                  `catch Panic(uint256 code)    { ... }`
        //                  `catch (bytes memory reason)  { ... bytes4(reason) ... }`
        e; kind; label;
        revert("Solution.classify: not implemented");
    }
}
