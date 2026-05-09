// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {VulnerableSigClaim} from "../src/signature-replay/VulnerableSigClaim.sol";
import {SafeSigClaim} from "../src/signature-replay/SafeSigClaim.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SignatureReplayTest is Test {
    uint256 internal signerPk = 0xCAFE;
    address internal signer;
    address payable internal recipient = payable(address(0xA11CE));

    function setUp() public {
        signer = vm.addr(signerPk);
    }

    function test_VulnerableSigClaimAllowsReplay() public {
        VulnerableSigClaim claim = new VulnerableSigClaim(signer);
        vm.deal(address(claim), 10 ether);

        bytes32 raw = keccak256(abi.encode(recipient, uint256(1 ether)));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Use the same signature 3 times → 3 ETH is withdrawn (replay)
        claim.claim(recipient, 1 ether, sig);
        claim.claim(recipient, 1 ether, sig);
        claim.claim(recipient, 1 ether, sig);
        assertEq(recipient.balance, 3 ether);
    }

    function test_SafeSigClaimRejectsReplay() public {
        SafeSigClaim claim = new SafeSigClaim(signer);
        vm.deal(address(claim), 10 ether);

        uint256 amount = 1 ether;
        uint256 nonce = 1;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 typehash =
            keccak256("Claim(address to,uint256 amount,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(typehash, recipient, amount, nonce, deadline));

        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", claim.domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        // First call succeeds
        claim.claim(recipient, amount, nonce, deadline, sig);
        assertEq(recipient.balance, 1 ether);

        // Second attempt — rejected with nonce used
        vm.expectRevert(bytes("nonce used"));
        claim.claim(recipient, amount, nonce, deadline, sig);
    }

    function test_SafeSigClaimRejectsExpired() public {
        SafeSigClaim claim = new SafeSigClaim(signer);
        vm.deal(address(claim), 10 ether);

        uint256 deadline = block.timestamp + 10;
        bytes32 typehash =
            keccak256("Claim(address to,uint256 amount,uint256 nonce,uint256 deadline)");
        bytes32 structHash =
            keccak256(abi.encode(typehash, recipient, uint256(1 ether), uint256(1), deadline));

        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", claim.domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.warp(deadline + 1);
        vm.expectRevert(bytes("expired"));
        claim.claim(recipient, 1 ether, 1, deadline, sig);
    }
}
