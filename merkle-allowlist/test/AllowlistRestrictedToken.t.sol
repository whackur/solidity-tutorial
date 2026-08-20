// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MerkleAllowlist} from "../src/MerkleAllowlist.sol";
import {AllowlistRestrictedToken} from "../src/AllowlistRestrictedToken.sol";
import {MerkleTreeLib} from "./MerkleTreeLib.sol";

contract AllowlistRestrictedTokenTest is Test {
    using MerkleTreeLib for bytes32[];

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal mallory = makeAddr("mallory");

    MerkleAllowlist internal allowlist;
    AllowlistRestrictedToken internal token;
    bytes32[] internal leaves;

    function setUp() public {
        leaves.push(_leaf(alice));
        leaves.push(_leaf(bob));

        allowlist = new MerkleAllowlist(leaves.root(), owner);
        token = new AllowlistRestrictedToken(allowlist, alice, 1000 ether);

        vm.prank(alice);
        allowlist.register(leaves.proof(0));
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account))));
    }

    function test_RevertWhen_RecipientIsNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(bob, 10 ether);
    }

    function test_AllowedAddressesCanTransfer() public {
        vm.prank(bob);
        allowlist.register(leaves.proof(1));

        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_RevocationBlocksTheNextTransfer() public {
        vm.prank(bob);
        allowlist.register(leaves.proof(1));

        vm.prank(alice);
        token.transfer(bob, 10 ether);

        vm.prank(owner);
        allowlist.revoke(bob);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, bob)
        );
        token.transfer(alice, 1 ether);
    }

    function test_RevertWhen_UnregisteredSenderTransfers() public {
        deal(address(token), mallory, 1 ether);

        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, mallory)
        );
        token.transfer(alice, 1 ether);
    }

    function test_MintCanIssueToUnregisteredAddressButTransferStillChecksGate() public {
        token.mint(mallory, 10 ether);
        assertEq(token.balanceOf(mallory), 10 ether);

        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(AllowlistRestrictedToken.AddressNotAllowed.selector, mallory)
        );
        token.transfer(alice, 1 ether);
    }

    function test_SystemAddressCanTransferWithoutMerkleRegistration() public {
        vm.prank(owner);
        allowlist.setSystemAddress(mallory, true);
        token.mint(mallory, 10 ether);

        vm.prank(mallory);
        token.transfer(alice, 1 ether);

        assertEq(token.balanceOf(alice), 1001 ether);
    }
}
