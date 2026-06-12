// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Public-mint mock ERC-20 — the lab mints the seed balance into
///         each claim contract. No faucet rate limit; tutorial only.
contract Q10MockToken is ERC20 {
    constructor() ERC20("ReplayToken", "TKN") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Intentionally-broken signed claim. The signed payload is just
///         `keccak256(abi.encode(to, amount))` — no nonce, no deadline,
///         no chainId, no verifyingContract.
contract Q10VulnerableSigClaim {
    address public immutable signer;
    Q10MockToken public immutable token;

    constructor(address s, Q10MockToken t) {
        signer = s;
        token = t;
    }

    function claim(address to, uint256 amount, bytes calldata signature) external {
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == signer, "bad sig");

        token.transfer(to, amount);
    }
}

/// @notice Multi-tenant lab. Each user calls `createInstance(signerAddr)`
///         once to get their own `Q10VulnerableSigClaim` pre-funded with a
///         dedicated mock token and study weak signing context.
///
///         Deploying costs only gas — the lab MINTS the seed tokens, it does
///         not need to hold any ETH.
contract Q10ReplayLab is SolvableBase {
    uint256 public constant SEED = 5e18; // 5 TKN (18 decimals)

    mapping(address => Q10VulnerableSigClaim) private _claims;

    event InstanceCreated(address indexed user, address claim, address signer, address token);

    function createInstance(address signer) external returns (address claim) {
        require(address(_claims[msg.sender]) == address(0), "already created");
        require(signer != address(0), "signer = 0");

        Q10MockToken t = new Q10MockToken();
        Q10VulnerableSigClaim c = new Q10VulnerableSigClaim(signer, t);
        t.mint(address(c), SEED);

        _claims[msg.sender] = c;
        emit InstanceCreated(msg.sender, address(c), signer, address(t));
        return address(c);
    }

    function claimOf(address user) external view returns (Q10VulnerableSigClaim) {
        return _claims[user];
    }

    function tokenOf(address user) external view returns (Q10MockToken) {
        Q10VulnerableSigClaim c = _claims[user];
        if (address(c) == address(0)) return Q10MockToken(address(0));
        return c.token();
    }

    function isSolved(address user) public view override returns (bool) {
        Q10VulnerableSigClaim c = _claims[user];
        if (address(c) == address(0)) return false;
        return c.token().balanceOf(address(c)) == 0;
    }
}
