// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title SafeSigClaim — EIP-712 + nonce + deadline + 4-way domain replay protection
/// @notice
///   - nonce            : prevents *reusing the same signature*
///   - deadline         : blocks use of expired signatures
///   - chainId          : prevents cross-replay on other chains (included in the EIP-712 domain)
///   - verifyingContract: prevents cross-replay on other contracts (included in the EIP-712 domain)
contract SafeSigClaim is EIP712 {
    bytes32 private constant _CLAIM_TYPEHASH =
        keccak256("Claim(address to,uint256 amount,uint256 nonce,uint256 deadline)");

    address public immutable signer;
    mapping(uint256 => bool) public usedNonces;

    constructor(address s) EIP712("SafeSigClaim", "1") {
        signer = s;
    }

    /// @notice Exposed so external signers can build the typed-data digest
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function claim(
        address payable to,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "expired");
        require(!usedNonces[nonce], "nonce used");

        bytes32 structHash =
            keccak256(abi.encode(_CLAIM_TYPEHASH, to, amount, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = ECDSA.recover(digest, signature);
        require(recovered == signer, "bad sig");

        usedNonces[nonce] = true;

        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
