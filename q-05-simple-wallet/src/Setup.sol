// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Local copy of ../simple-wallet/src/SimpleWallet.sol — kept self-contained.
contract SimpleWallet {
    mapping(address => uint256) private _ethBalances;
    mapping(address => mapping(address => uint256)) private _erc20Balances;

    receive() external payable {
        depositEth();
    }

    function depositEth() public payable {
        _ethBalances[msg.sender] += msg.value;
    }

    function withdrawEth(uint256 amount) public {
        require(_ethBalances[msg.sender] >= amount, "Insufficient ETH balance");
        _ethBalances[msg.sender] -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
    }

    function getEthBalance() public view returns (uint256) {
        return _ethBalances[msg.sender];
    }

    function depositErc20(address tokenAddress, uint256 amount) public {
        require(amount > 0, "amount must be > 0");
        _erc20Balances[msg.sender][tokenAddress] += amount;
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawErc20(address tokenAddress, uint256 amount) public {
        require(_erc20Balances[msg.sender][tokenAddress] >= amount, "Insufficient token balance");
        _erc20Balances[msg.sender][tokenAddress] -= amount;
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
