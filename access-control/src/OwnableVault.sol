// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title OwnableVault — single-owner model
/// @notice "One owner holds every privilege". Used as the comparison baseline against RoleManagedVault.
contract OwnableVault is Ownable {
    mapping(address => uint256) public balanceOf;
    bool public paused;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function mint(address to, uint256 amount) external onlyOwner {
        require(!paused, "paused");
        balanceOf[to] += amount;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
