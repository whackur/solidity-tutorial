// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {MyForwarder, MetaCounter} from "../src/Setup.sol";

/// @notice Proves the intended solve path: a forwarder-relayed, EIP-712-signed
///         ForwardRequest credits the signer via _msgSender(), while a direct
///         EOA call reverts.
contract SolveTest is Test {
    MyForwarder forwarder;
    MetaCounter counter;
    uint256 userPk = 0xA11CE;
    address user;

    bytes32 constant FORWARD_REQUEST_TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
    );
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        user = vm.addr(userPk);
        forwarder = new MyForwarder();
        counter = new MetaCounter(address(forwarder));
    }

    function test_directCallReverts() public {
        vm.prank(user);
        vm.expectRevert(MetaCounter.MustGoThroughForwarder.selector);
        counter.increment();
    }

    function test_forwarderRelayedSolve() public {
        bytes memory data = abi.encodeCall(MetaCounter.increment, ());
        uint256 nonce = forwarder.nonces(user);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint256 gas = 200_000;

        bytes32 structHash =
            keccak256(abi.encode(FORWARD_REQUEST_TYPEHASH, user, address(counter), 0, gas, nonce, deadline, keccak256(data)));
        bytes32 domainSep = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256("MyForwarder"), keccak256("1"), block.chainid, address(forwarder))
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        ERC2771Forwarder.ForwardRequestData memory req = ERC2771Forwarder.ForwardRequestData({
            from: user,
            to: address(counter),
            value: 0,
            gas: gas,
            deadline: deadline,
            data: data,
            signature: abi.encodePacked(r, s, v)
        });

        // Anyone may relay; address(this) pays gas, but the signer is credited.
        forwarder.execute(req);

        assertEq(counter.counterOf(user), 1, "signer should be credited");
        assertTrue(counter.isSolved(user), "isSolved after relayed increment");
    }
}
