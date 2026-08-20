// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Default-allow registry for operational transfer blocks.
contract AddressBlocklist is Ownable {
    mapping(address account => bool) private _blocked;

    event BlockStatusUpdated(address indexed account, bool blocked);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setBlocked(address account, bool blocked) external onlyOwner {
        _blocked[account] = blocked;
        emit BlockStatusUpdated(account, blocked);
    }

    function isBlocked(address account) external view returns (bool) {
        return _blocked[account];
    }
}
