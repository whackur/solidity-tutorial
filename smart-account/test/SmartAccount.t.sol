// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {SmartAccount} from "../src/SmartAccount.sol";
import {ISmartAccount} from "../src/interfaces/ISmartAccount.sol";

/// @dev Receives ETH and exposes a counter to verify {execute} / {executeBatch}
///      successfully forward calls and value.
contract Sink {
    uint256 public counter;
    uint256 public received;

    function bump(uint256 amount) external payable {
        counter += amount;
        received += msg.value;
    }
}

/// @notice EIP-7702 delegation is simulated by deploying SmartAccount and using
///         `vm.etch` to copy its runtime to an EOA address. After etch, the EOA
///         and the implementation runtime are functionally identical, so
///         `address(this)` inside the etched account equals the EOA address.
contract SmartAccountTest is Test {
    SmartAccount internal implementation;
    Sink internal sink;

    Vm.Wallet internal owner;
    SmartAccount internal account;

    function setUp() public {
        implementation = new SmartAccount();
        sink = new Sink();
        owner = vm.createWallet("owner");

        vm.etch(owner.addr, address(implementation).code);
        account = SmartAccount(payable(owner.addr));
        vm.deal(owner.addr, 10 ether);
    }

    function test_executeBatchRequiresSelfCall() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(1, 0);
        vm.expectRevert(ISmartAccount.Unauthorized.selector);
        account.executeBatch(calls);
    }

    function test_executeBatchSucceedsViaSelfCall() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(3, 0);

        vm.prank(owner.addr);
        account.executeBatch(calls);

        assertEq(sink.counter(), 3);
    }

    function test_executeWithValidOwnerSignatureRunsBatch() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(7, 1 ether);
        uint48 validAfter = 0;
        uint48 validUntil = uint48(block.timestamp + 1 hours);

        bytes memory signature = _signBatch(calls, validAfter, validUntil);

        assertTrue(account.verifyExecuteSignature(calls, validAfter, validUntil, signature));

        address relayer = makeAddr("relayer");
        vm.prank(relayer);
        account.execute(calls, validAfter, validUntil, signature);

        assertEq(sink.counter(), 7);
        assertEq(sink.received(), 1 ether);
        assertEq(account.getNonce(), 1);
    }

    function test_executeRevertsOnTamperedCalls() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(1, 0);
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signBatch(calls, 0, validUntil);

        ISmartAccount.Call[] memory tampered = _singleBumpCall(99, 0);

        vm.expectRevert(ISmartAccount.InvalidSignature.selector);
        account.execute(tampered, 0, validUntil, signature);
    }

    function test_executeRevertsAfterValidUntilExpired() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(1, 0);
        uint48 validUntil = uint48(block.timestamp + 5 minutes);
        bytes memory signature = _signBatch(calls, 0, validUntil);

        vm.warp(uint256(validUntil) + 1);

        vm.expectRevert(abi.encodeWithSelector(ISmartAccount.ValidUntilExpired.selector, validUntil, block.timestamp));
        account.execute(calls, 0, validUntil, signature);
    }

    function test_executeConsumesNonceForReplayProtection() public {
        ISmartAccount.Call[] memory calls = _singleBumpCall(1, 0);
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signBatch(calls, 0, validUntil);

        account.execute(calls, 0, validUntil, signature);

        vm.expectRevert(ISmartAccount.InvalidSignature.selector);
        account.execute(calls, 0, validUntil, signature);
    }

    function test_isValidSignatureMatchesReplaySafeHash() public view {
        bytes32 raw = keccak256("hello black combat");
        bytes32 replaySafe = _replaySafeHash(raw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.privateKey, replaySafe);

        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(account.isValidSignature(raw, sig), bytes4(0x1626ba7e));

        bytes memory wrongSig = abi.encodePacked(r, s, uint8(v ^ 1));
        assertEq(account.isValidSignature(raw, wrongSig), bytes4(0xffffffff));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _singleBumpCall(uint256 amount, uint256 value) internal view returns (ISmartAccount.Call[] memory calls) {
        calls = new ISmartAccount.Call[](1);
        calls[0] = ISmartAccount.Call({
            target: address(sink),
            value: value,
            data: abi.encodeWithSelector(Sink.bump.selector, amount)
        });
    }

    function _signBatch(ISmartAccount.Call[] memory calls, uint48 validAfter, uint48 validUntil)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = account.computeBatchDigest(account.getNonce(), validAfter, validUntil, calls);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _replaySafeHash(bytes32 hash) internal view returns (bytes32) {
        bytes32 messageTypehash = keccak256("SmartAccountMessage(bytes32 hash)");
        bytes32 structHash = keccak256(abi.encode(messageTypehash, hash));
        return keccak256(abi.encodePacked("\x19\x01", account.domainSeparator(), structHash));
    }
}
