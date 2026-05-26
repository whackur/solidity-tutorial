// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Public-mint ERC20 paired with the voucher challenge. The challenge
///         contract itself is the only address allowed to mint outside the
///         standard faucet path, but a public mint is left open so students
///         can also use this token in other tutorials.
contract VoucherToken is ERC20 {
    constructor() ERC20("Voucher", "VCH") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Multi-tenant EIP-712 voucher lab. A single instance is shared.
///         Users sign a Voucher struct off-chain (EIP-712 typed data) and
///         submit it on-chain to mint themselves tokens. The signer must
///         equal the named redeemer to keep the challenge per-user-solo.
///
///         isSolved(user) becomes true once the user redeems any voucher
///         where they were both signer and redeemer.
contract VoucherChallenge is EIP712, SolvableBase {
    bytes32 public constant VOUCHER_TYPEHASH = keccak256(
        "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
    );

    VoucherToken public immutable token;

    mapping(uint256 => bool) public usedVouchers;
    mapping(address => bool) public solved;

    event VoucherRedeemed(
        address indexed signer,
        address indexed redeemer,
        uint256 voucherId,
        uint256 amount
    );

    constructor() EIP712("MyEIP712App", "1") {
        token = new VoucherToken();
    }

    /// @notice Redeem a signed voucher. The signer must equal the redeemer
    ///         (so users solve the challenge using their own wallet).
    function redeemVoucher(
        address signer,
        address redeemer,
        uint256 voucherId,
        uint256 amount,
        bytes calldata signature
    ) external {
        require(!usedVouchers[voucherId], "Voucher already redeemed");
        require(amount > 0, "amount must be > 0");
        require(msg.sender == redeemer, "Only the specified redeemer can call this");
        require(signer == redeemer, "signer must equal redeemer for solo solve");

        bytes32 structHash =
            keccak256(abi.encode(VOUCHER_TYPEHASH, address(token), signer, redeemer, voucherId, amount));
        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(recoveredSigner == signer, "Invalid signature");

        usedVouchers[voucherId] = true;
        solved[signer] = true;

        token.mint(redeemer, amount);
        emit VoucherRedeemed(signer, redeemer, voucherId, amount);
    }

    /// @notice Helper view returning the EIP-712 digest a user must sign.
    ///         Web UIs can use this to verify their off-chain payload matches.
    function computeDigest(address signer, address redeemer, uint256 voucherId, uint256 amount)
        external
        view
        returns (bytes32)
    {
        bytes32 structHash =
            keccak256(abi.encode(VOUCHER_TYPEHASH, address(token), signer, redeemer, voucherId, amount));
        return _hashTypedDataV4(structHash);
    }

    /// @notice Exposes the EIP-712 domain separator for off-chain wallets.
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function isSolved(address user) public view override returns (bool) {
        return solved[user];
    }
}
