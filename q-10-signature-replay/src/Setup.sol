// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Intentionally-broken signed claim. The signed payload is just
///         `keccak256(abi.encode(to, amount))` — no nonce, no deadline,
///         no chainId, no verifyingContract.
contract Q10VulnerableSigClaim {
    address public immutable signer;

    constructor(address s) {
        signer = s;
    }

    function claim(address payable to, uint256 amount, bytes calldata signature) external {
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == signer, "bad sig");

        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}

/// @notice Multi-tenant lab. Each user calls `createInstance(signerAddr)`
///         once to get their own pre-funded `Q10VulnerableSigClaim` and
///         study weak signing context.
///
///         The lab itself must hold ≥ `SEED * N` ETH at deploy time —
///         see the funded `receive()`.
contract Q10ReplayLab is SolvableBase {
    uint256 public constant SEED = 5 ether;

    mapping(address => Q10VulnerableSigClaim) private _claims;

    event InstanceCreated(address indexed user, address claim, address signer);

    receive() external payable {}

    function createInstance(address signer) external returns (address claim) {
        require(address(_claims[msg.sender]) == address(0), "already created");
        require(signer != address(0), "signer = 0");
        require(address(this).balance >= SEED, "lab underfunded");

        Q10VulnerableSigClaim c = new Q10VulnerableSigClaim(signer);
        (bool ok,) = address(c).call{value: SEED}("");
        require(ok, "seed failed");

        _claims[msg.sender] = c;
        emit InstanceCreated(msg.sender, address(c), signer);
        return address(c);
    }

    function claimOf(address user) external view returns (Q10VulnerableSigClaim) {
        return _claims[user];
    }

    function isSolved(address user) public view override returns (bool) {
        Q10VulnerableSigClaim c = _claims[user];
        if (address(c) == address(0)) return false;
        return address(c).balance == 0;
    }
}
