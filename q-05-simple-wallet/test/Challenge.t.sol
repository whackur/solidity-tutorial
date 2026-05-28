// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q05SimpleWallet, Q05MockERC20} from "../src/Setup.sol";

contract Q05WalletPublicTest is Test {
    Q05SimpleWallet internal wallet;
    Q05MockERC20 internal token;
    address internal alice = makeAddr("alice");

    function setUp() public {
        wallet = new Q05SimpleWallet();
        token = new Q05MockERC20();
        vm.deal(alice, 1 ether);
    }

    function test_InitialStateIsUnsolved() public view {
        assertEq(wallet.ethBalanceOf(alice), 0);
        assertEq(wallet.erc20BalanceOf(alice, address(token)), 0);
        assertFalse(wallet.isSolved(alice));
    }

    function test_DepositAloneDoesNotSolve() public {
        vm.prank(alice);
        wallet.depositEth{value: 1 wei}();

        assertEq(wallet.ethBalanceOf(alice), 1 wei);
        assertFalse(wallet.isSolved(alice));
    }
}
