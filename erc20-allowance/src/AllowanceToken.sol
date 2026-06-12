// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AllowanceToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 amount) ERC20(name_, symbol_) {
        _mint(msg.sender, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
