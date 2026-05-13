// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Solution} from "../src/Solution.sol";

contract Q07EthSignTest is Test {
    Solution internal sol;

    address internal signer;
    uint256 internal signerPk;

    function setUp() public {
        sol = new Solution();
        (signer, signerPk) = makeAddrAndKey("signer");
    }

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_RecoverEthSign() public view {
        bytes32 hash = keccak256("hello eth_sign");
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
        bytes memory sig = _sign(signerPk, digest);

        assertEq(sol.recoverEthSign(hash, sig), signer, "eth_sign recovery");
    }

    function test_RecoverPersonalSign() public view {
        bytes memory msg_ = bytes("hello, personal_sign world!");
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(msg_);
        bytes memory sig = _sign(signerPk, digest);

        assertEq(sol.recoverPersonalSign(msg_, sig), signer, "personal_sign recovery");
    }

    function test_WrongSignerFails() public {
        (, uint256 otherPk) = makeAddrAndKey("other");
        bytes32 hash = keccak256("x");
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(hash);
        bytes memory sig = _sign(otherPk, digest);

        address recovered = sol.recoverEthSign(hash, sig);
        assertTrue(recovered != signer, "must not equal expected signer");
    }
}
