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

    function setUp() public {
        allowlist = new MerkleAllowlist();
        token = new AllowlistRestrictedToken(allowlist, alice, 1000 ether);

        vm.startPrank(alice);
        allowlist.commitRoot(_root(alice, 0, _leaf(bob, 0), 0));
        allowlist.register(0, _proof(_leaf(bob, 0)));
        vm.stopPrank();
    }

    function _leaf(address account, uint256 registrationCounter) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, registrationCounter))));
    }

    function _root(address account, uint256 registrationCounter, bytes32 sibling, uint256 index)
        internal
        pure
        returns (bytes32)
    {
        bytes32 leaf = _leaf(account, registrationCounter);
        bytes32 node = index & 1 == 0
            ? keccak256(abi.encode(leaf, sibling))
            : keccak256(abi.encode(sibling, leaf));
        node = keccak256(abi.encode(node, bytes32(0)));
        return keccak256(abi.encode(node, bytes32(0)));
    }

    function _proof(bytes32 sibling) internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](3);
        proof[0] = sibling;
    }

    function test_RevertWhen_RecipientIsNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(bob, 10 ether);
    }

    function test_AllowedAddressesCanTransfer() public {
        vm.startPrank(bob);
        allowlist.commitRoot(_root(bob, 0, _leaf(alice, 0), 1));
        allowlist.register(1, _proof(_leaf(alice, 0)));
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_SelfRevocationBlocksTheNextTransfer() public {
        vm.startPrank(bob);
        allowlist.commitRoot(_root(bob, 0, _leaf(alice, 0), 1));
        allowlist.register(1, _proof(_leaf(alice, 0)));
        allowlist.revoke();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(bob, 10 ether);
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
