// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

import {MyForwarder} from "../src/MyForwarder.sol";
import {MetaCounter} from "../src/MetaCounter.sol";

contract MetaTxTest is Test {
    bytes32 private constant _FORWARD_REQUEST_TYPEHASH =
        keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)");
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    MyForwarder internal forwarder;
    MetaCounter internal counter;
    Vm.Wallet internal user;
    address internal relayer = makeAddr("relayer");

    function setUp() public {
        forwarder = new MyForwarder();
        counter = new MetaCounter(address(forwarder));
        user = vm.createWallet("user");
        vm.deal(relayer, 10 ether);
    }

    function test_relayedIncrementCreditsActualSigner() public {
        ERC2771Forwarder.ForwardRequestData memory req = _buildRequest();
        req.signature = _signRequest(req);

        assertTrue(forwarder.verify(req));

        vm.prank(relayer);
        forwarder.execute(req);

        assertEq(counter.counterOf(user.addr), 1);
        assertEq(counter.counterOf(relayer), 0);
        assertEq(counter.lastCaller(), user.addr);
        assertEq(forwarder.nonces(user.addr), 1);
    }

    function test_replayRevertsBecauseNonceConsumed() public {
        ERC2771Forwarder.ForwardRequestData memory req = _buildRequest();
        req.signature = _signRequest(req);

        vm.prank(relayer);
        forwarder.execute(req);

        vm.prank(relayer);
        vm.expectRevert();
        forwarder.execute(req);
    }

    function test_executeRevertsAfterDeadline() public {
        ERC2771Forwarder.ForwardRequestData memory req = _buildRequest();
        req.signature = _signRequest(req);

        vm.warp(uint256(req.deadline) + 1);

        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(ERC2771Forwarder.ERC2771ForwarderExpiredRequest.selector, req.deadline));
        forwarder.execute(req);
    }

    function test_executeRevertsOnSignatureMismatch() public {
        ERC2771Forwarder.ForwardRequestData memory req = _buildRequest();
        req.signature = _signRequest(req);

        Vm.Wallet memory imposter = vm.createWallet("imposter");
        req.from = imposter.addr;

        vm.prank(relayer);
        vm.expectRevert();
        forwarder.execute(req);
    }

    function test_directCallFallsBackToMsgSender() public {
        vm.prank(user.addr);
        counter.increment();

        assertEq(counter.counterOf(user.addr), 1);
        assertEq(counter.lastCaller(), user.addr);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildRequest() internal view returns (ERC2771Forwarder.ForwardRequestData memory req) {
        req = ERC2771Forwarder.ForwardRequestData({
            from: user.addr,
            to: address(counter),
            value: 0,
            gas: 200_000,
            deadline: uint48(block.timestamp + 1 hours),
            data: abi.encodeCall(MetaCounter.increment, ()),
            signature: ""
        });
    }

    function _signRequest(ERC2771Forwarder.ForwardRequestData memory req) internal view returns (bytes memory) {
        bytes32 digest = _digest(req, forwarder.nonces(user.addr));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _digest(ERC2771Forwarder.ForwardRequestData memory req, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                _FORWARD_REQUEST_TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                nonce,
                req.deadline,
                keccak256(req.data)
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("MyForwarder")),
                keccak256(bytes("1")),
                block.chainid,
                address(forwarder)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
