// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

/// @notice Concrete instantiation of OpenZeppelin's ERC-2771 forwarder. The
///         EIP-712 domain `name` matches the value passed here and is
///         load-bearing for off-chain signers.
contract MyForwarder is ERC2771Forwarder {
    constructor() ERC2771Forwarder("MyForwarder") {}
}
