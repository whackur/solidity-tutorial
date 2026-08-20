// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AddressBlocklist} from "../src/AddressBlocklist.sol";
import {BlocklistRestrictedToken} from "../src/BlocklistRestrictedToken.sol";

contract TransferBlocklistTest is Test {
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    AddressBlocklist internal blocklist;
    BlocklistRestrictedToken internal token;

    function setUp() public {
        blocklist = new AddressBlocklist(owner);
        token = new BlocklistRestrictedToken(blocklist, alice, 1000 ether);
    }

    function test_DefaultAllowsTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_BlockedSenderCannotTransfer() public {
        vm.prank(owner);
        blocklist.setBlocked(alice, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BlocklistRestrictedToken.AddressBlocked.selector, alice)
        );
        token.transfer(bob, 10 ether);
    }

    function test_BlockedRecipientCannotReceive() public {
        vm.prank(owner);
        blocklist.setBlocked(bob, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BlocklistRestrictedToken.AddressBlocked.selector, bob)
        );
        token.transfer(bob, 10 ether);
    }

    function test_UnblockRestoresTransfer() public {
        vm.startPrank(owner);
        blocklist.setBlocked(bob, true);
        blocklist.setBlocked(bob, false);
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 10 ether);
        assertEq(token.balanceOf(bob), 10 ether);
    }

    function test_NonOwnerCannotChangeBlockStatus() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        blocklist.setBlocked(bob, true);
    }

    function test_ClassroomMintDoesNotRequireTransferEligibility() public {
        vm.prank(owner);
        blocklist.setBlocked(bob, true);

        token.mint(bob, 10 ether);
        assertEq(token.balanceOf(bob), 10 ether);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(BlocklistRestrictedToken.AddressBlocked.selector, bob)
        );
        token.transfer(alice, 1 ether);
    }
}
