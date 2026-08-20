// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";
import {AllowlistRestrictedToken} from "../src/AllowlistRestrictedToken.sol";

contract AllowlistRestrictedTokenTest is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal mallory = makeAddr("mallory");

    MerkleAllowlist internal allowlist;
    AllowlistRestrictedToken internal token;

    /// @dev The shared list: alice at slot 0, bob at slot 1, filler elsewhere.
    address[8] internal members;
    bytes32[8] internal leaves;
    bytes32 internal root;

    function setUp() public {
        allowlist = new MerkleAllowlist();
        token = new AllowlistRestrictedToken(allowlist, alice, 1000 ether);

        members[0] = alice;
        members[1] = bob;
        for (uint256 slot = 2; slot < 8; slot++) {
            members[slot] = makeAddr(string.concat("member", vm.toString(slot)));
        }
        for (uint256 slot = 0; slot < 8; slot++) {
            leaves[slot] = _leaf(members[slot]);
        }
        root = _root(leaves);

        vm.startPrank(alice);
        allowlist.commitRoot(root);
        allowlist.register(0, _proof(leaves, 0));
        vm.stopPrank();
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    function _root(bytes32[8] memory list) internal pure returns (bytes32) {
        bytes32[4] memory level1;
        for (uint256 i = 0; i < 4; i++) {
            level1[i] = keccak256(abi.encode(list[i * 2], list[i * 2 + 1]));
        }
        bytes32 left = keccak256(abi.encode(level1[0], level1[1]));
        bytes32 right = keccak256(abi.encode(level1[2], level1[3]));
        return keccak256(abi.encode(left, right));
    }

    function _proof(bytes32[8] memory list, uint256 index)
        internal
        pure
        returns (bytes32[] memory proof)
    {
        proof = new bytes32[](3);
        proof[0] = list[index ^ 1];

        bytes32[4] memory level1;
        for (uint256 i = 0; i < 4; i++) {
            level1[i] = keccak256(abi.encode(list[i * 2], list[i * 2 + 1]));
        }
        proof[1] = level1[(index / 2) ^ 1];

        bytes32[2] memory level2;
        level2[0] = keccak256(abi.encode(level1[0], level1[1]));
        level2[1] = keccak256(abi.encode(level1[2], level1[3]));
        proof[2] = level2[(index / 4) ^ 1];
    }

    function _registerBob() internal {
        vm.startPrank(bob);
        allowlist.commitRoot(root);
        allowlist.register(1, _proof(leaves, 1));
        vm.stopPrank();
    }

    function test_RevertWhen_RecipientIsNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(bob, 10 ether);
    }

    function test_AllowedAddressesCanTransfer() public {
        // Bob is in the same list and commits the same root as alice did.
        _registerBob();

        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_SelfRevocationBlocksTheNextTransfer() public {
        _registerBob();

        vm.prank(bob);
        allowlist.revoke();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(bob, 10 ether);
    }

    function test_RevokedAddressCanRegisterAgainWithTheSameProof() public {
        _registerBob();

        vm.startPrank(bob);
        allowlist.revoke();
        allowlist.register(1, _proof(leaves, 1));
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_RevertWhen_UnregisteredSenderTransfers() public {
        deal(address(token), mallory, 1 ether);

        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, mallory)
        );
        token.transfer(alice, 1 ether);
    }
}
