// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Minimal hand-rolled ERC-20 (no inheritance, no libraries) so a
///         beginner sees the raw allowance + transferFrom flow on a 60-line
///         contract. Solver's mental model: balances[] is the ledger and
///         allowance[owner][spender] is a per-spender spending budget.
contract Q20MiniERC20 {
    string public name = "Mini Token";
    string public symbol = "MNT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 cur = allowance[from][msg.sender];
        require(cur >= amount, "allowance");
        require(balanceOf[from] >= amount, "balance");
        if (cur != type(uint256).max) {
            allowance[from][msg.sender] = cur - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/// @notice Shared faucet — each user can call `claim()` exactly once to
///         receive CLAIM_AMOUNT of MNT. Per-user state via `claimed[]`.
contract Q20Faucet is Q20MiniERC20 {
    uint256 public constant CLAIM_AMOUNT = 100e18;
    mapping(address => bool) public claimed;

    function claim() external {
        require(!claimed[msg.sender], "already claimed");
        claimed[msg.sender] = true;
        _mint(msg.sender, CLAIM_AMOUNT);
    }
}

/// @notice Shared "vault" that pulls tokens from the caller via
///         `transferFrom`. The caller must approve this vault first;
///         otherwise the inner `transferFrom` reverts with `"allowance"`.
///         `deposited[]` tracks each user's pulled total so `isSolved`
///         can verify they really went through approve+pull rather than
///         a plain `transfer`.
contract Q20PullVault {
    Q20Faucet public immutable token;
    mapping(address => uint256) public deposited;

    constructor(Q20Faucet t) {
        token = t;
    }

    function pull(uint256 amount) external {
        // Pull `amount` tokens from the caller into this vault.
        // The vault is the spender; `msg.sender` is the token holder.
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");
        deposited[msg.sender] += amount;
    }
}

/// @notice Multi-tenant beginner ERC-20 lab. A single Q20Faucet + a single
///         Q20PullVault are deployed once; users solve in parallel because
///         all per-user state lives in `claimed[]` and `deposited[]`.
contract Q20Erc20BasicLab is SolvableBase {
    Q20Faucet public immutable faucet;
    Q20PullVault public immutable vault;
    uint256 public constant TARGET = 25e18;

    constructor() {
        faucet = new Q20Faucet();
        vault = new Q20PullVault(faucet);
    }

    function isSolved(address user) public view override returns (bool) {
        return faucet.claimed(user) && vault.deposited(user) >= TARGET;
    }
}
