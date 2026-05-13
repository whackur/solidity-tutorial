// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {SignatureVerifier} from "../src/SignatureVerifier.sol";

contract SignatureVerifierTest is Test {
    SignatureVerifier internal verifier;

    uint256 internal signerKey = 0xA11CE;
    address internal signer;
    address internal otherSigner = address(0xBEEF);

    function setUp() public {
        verifier = new SignatureVerifier();
        signer = vm.addr(signerKey);
    }

    function _ethSignedHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function _personalSignHash(bytes memory message) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", _uintToString(message.length), message)
        );
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // ----- eth_sign -----

    function test_RecoverEthSignSigner() public view {
        bytes32 messageHash = keccak256(bytes("Hello, Ethereum!"));
        bytes32 digest = _ethSignedHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertEq(verifier.recoverEthSignSigner(messageHash, sig), signer);
    }

    function test_VerifyEthSignWithExpectedSigner() public view {
        bytes32 messageHash = keccak256(bytes("Test Message"));
        bytes32 digest = _ethSignedHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertTrue(verifier.verifyEthSign(messageHash, sig, signer));
    }

    function test_VerifyEthSignFailsWithWrongSigner() public view {
        bytes32 messageHash = keccak256(bytes("Test Message"));
        bytes32 digest = _ethSignedHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertFalse(verifier.verifyEthSign(messageHash, sig, otherSigner));
    }

    // ----- personal_sign -----

    function test_RecoverPersonalSignSigner() public view {
        bytes memory message = bytes("Hello, Ethereum Personal Sign!");
        bytes32 digest = _personalSignHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertEq(verifier.recoverPersonalSignSigner(message, sig), signer);
    }

    function test_VerifyPersonalSignWithExpectedSigner() public view {
        bytes memory message = bytes("Test Personal Sign");
        bytes32 digest = _personalSignHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertTrue(verifier.verifyPersonalSign(message, sig, signer));
    }

    function test_VerifyPersonalSignFailsWithWrongSigner() public view {
        bytes memory message = bytes("Test Personal Sign Fail");
        bytes32 digest = _personalSignHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertFalse(verifier.verifyPersonalSign(message, sig, otherSigner));
    }

    function test_HandlesUtf8Messages() public view {
        // UTF-8 encoded bytes for "Hello, Ethereum!"
        bytes memory message = hex"ec9588eb8595ed9598ec84b8ec9a942c20ec9db4eb8d94eba6acec9aa421";
        bytes32 digest = _personalSignHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertEq(verifier.recoverPersonalSignSigner(message, sig), signer);
    }
}
