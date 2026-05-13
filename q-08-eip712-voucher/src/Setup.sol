// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Local copy of ../eip-712-voucher/src/Voucher.sol
contract Voucher is EIP712 {
    bytes32 public constant VOUCHER_TYPEHASH = keccak256(
        "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
    );

    mapping(uint256 => bool) public usedVouchers;

    event VoucherRedeemed(
        address indexed token,
        address indexed signer,
        address indexed redeemer,
        uint256 voucherId,
        uint256 amount
    );

    constructor() EIP712("MyEIP712App", "1") {}

    function redeemVoucher(
        address token,
        address signer,
        address redeemer,
        uint256 voucherId,
        uint256 amount,
        bytes calldata signature
    ) external {
        require(!usedVouchers[voucherId], "Voucher already redeemed");
        require(msg.sender == redeemer, "Only the specified redeemer can call this");

        bytes32 structHash =
            keccak256(abi.encode(VOUCHER_TYPEHASH, token, signer, redeemer, voucherId, amount));

        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(digest, signature);

        require(recoveredSigner == signer, "Invalid signature");
        require(recoveredSigner != address(0), "Invalid signature (recovered zero address)");

        usedVouchers[voucherId] = true;

        IERC20(token).transferFrom(signer, redeemer, amount);

        emit VoucherRedeemed(token, signer, redeemer, voucherId, amount);
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
