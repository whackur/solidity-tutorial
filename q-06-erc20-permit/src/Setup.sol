// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract PermitToken is ERC20, ERC20Permit {
    constructor() ERC20("PermitToken", "PT") ERC20Permit("PermitToken") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
