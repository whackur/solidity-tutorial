// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract MyERC20Test is Test {
    MyERC20 internal token;
    address internal owner = address(this);
    address internal other = address(0xBEEF);

    function setUp() public {
        token = new MyERC20("MyERC20", "ME2", 1_000);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "MyERC20");
        assertEq(token.symbol(), "ME2");
    }

    function test_TotalSupplyAssignedToOwner() public view {
        assertEq(token.totalSupply(), token.balanceOf(owner));
    }

    function test_TransferBetweenAccounts() public {
        token.transfer(other, 50);
        assertEq(token.balanceOf(other), 50);

        vm.prank(other);
        token.transfer(owner, 50);
        assertEq(token.balanceOf(other), 0);
        assertEq(token.balanceOf(owner), 1_000);
    }

    function test_MintIncreasesBalance() public {
        token.mint(other, 123);
        assertEq(token.balanceOf(other), 123);
    }

    function test_BurnReducesBalance() public {
        token.mint(other, 200);
        token.burn(other, 50);
        assertEq(token.balanceOf(other), 150);
    }
}
