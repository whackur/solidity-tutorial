// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Multi-tenant wallet supporting ETH + any ERC-20 deposit/withdraw.
///         Per-user balances and per-user solve flags. A single instance
///         is shared; users do not interfere.
contract SimpleWallet is SolvableBase {
    mapping(address => uint256) private _ethBalances;
    mapping(address => mapping(address => uint256)) private _erc20Balances;

    mapping(address => bool) public depositedEth;
    mapping(address => bool) public withdrewEth;
    mapping(address => bool) public depositedErc20;
    mapping(address => bool) public withdrewErc20;

    receive() external payable {
        depositEth();
    }

    function depositEth() public payable {
        require(msg.value > 0, "value must be > 0");
        _ethBalances[msg.sender] += msg.value;
        depositedEth[msg.sender] = true;
    }

    function withdrawEth(uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        require(_ethBalances[msg.sender] >= amount, "Insufficient ETH balance");
        _ethBalances[msg.sender] -= amount;
        withdrewEth[msg.sender] = true;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
    }

    function ethBalanceOf(address user) external view returns (uint256) {
        return _ethBalances[user];
    }

    function depositErc20(address tokenAddress, uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        _erc20Balances[msg.sender][tokenAddress] += amount;
        depositedErc20[msg.sender] = true;
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawErc20(address tokenAddress, uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        require(
            _erc20Balances[msg.sender][tokenAddress] >= amount, "Insufficient token balance"
        );
        _erc20Balances[msg.sender][tokenAddress] -= amount;
        withdrewErc20[msg.sender] = true;
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function erc20BalanceOf(address user, address tokenAddress) external view returns (uint256) {
        return _erc20Balances[user][tokenAddress];
    }

    function isSolved(address user) public view override returns (bool) {
        return depositedEth[user] && withdrewEth[user] && depositedErc20[user]
            && withdrewErc20[user];
    }
}

/// @notice Public-mint mock ERC-20 — any user can mint themselves a balance
///         to play with. There is no faucet rate limit; it's only a tutorial.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
