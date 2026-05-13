// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {GameItems} from "../src/GameItems.sol";

contract GameItemsTest is Test {
    GameItems internal items;
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        items = new GameItems(owner);
    }

    function test_MintSingleAndBalance() public {
        items.mint(alice, items.GOLD(), 100, "");
        assertEq(items.balanceOf(alice, items.GOLD()), 100);
    }

    function test_MintBatchSetsAllBalances() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = items.GOLD();
        ids[1] = items.SILVER();
        ids[2] = items.SWORD();

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000;
        amounts[1] = 500;
        amounts[2] = 1;

        items.mintBatch(alice, ids, amounts, "");
        assertEq(items.balanceOf(alice, items.GOLD()), 1_000);
        assertEq(items.balanceOf(alice, items.SILVER()), 500);
        assertEq(items.balanceOf(alice, items.SWORD()), 1);
    }

    function test_BalanceOfBatch() public {
        items.mint(alice, items.GOLD(), 100, "");
        items.mint(bob, items.SILVER(), 50, "");

        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        uint256[] memory ids = new uint256[](2);
        ids[0] = items.GOLD();
        ids[1] = items.SILVER();

        uint256[] memory bals = items.balanceOfBatch(accounts, ids);
        assertEq(bals[0], 100);
        assertEq(bals[1], 50);
    }

    function test_SafeBatchTransferFromMovesAll() public {
        items.mint(alice, items.GOLD(), 100, "");
        items.mint(alice, items.SILVER(), 50, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = items.GOLD();
        ids[1] = items.SILVER();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30;
        amounts[1] = 20;

        vm.prank(alice);
        items.safeBatchTransferFrom(alice, bob, ids, amounts, "");
        assertEq(items.balanceOf(bob, items.GOLD()), 30);
        assertEq(items.balanceOf(bob, items.SILVER()), 20);
    }

    function test_URIIsSharedTemplate() public view {
        string memory expected = "ipfs://bafy.../{id}.json";
        // ERC-1155 spec: the *client* substitutes `{id}` with a 64-char hex string — the contract returns the same template
        assertEq(items.uri(items.GOLD()), expected);
        assertEq(items.uri(items.SWORD()), expected);
    }
}
