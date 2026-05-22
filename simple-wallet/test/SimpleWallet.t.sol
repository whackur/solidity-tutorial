// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {SimpleWallet} from "../src/SimpleWallet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract SimpleWalletTest is Test {
    SimpleWallet internal wallet;
    MockToken internal token;
    address internal user = address(0xBEEF);

    function setUp() public {
        wallet = new SimpleWallet();
        token = new MockToken();
    }

    function test_DepositAndWithdrawEth() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        wallet.depositEth{value: 3 ether}();

        vm.prank(user);
        assertEq(wallet.getEthBalance(), 3 ether);

        vm.prank(user);
        wallet.withdrawEth(1 ether);

        vm.prank(user);
        assertEq(wallet.getEthBalance(), 2 ether);
        assertEq(user.balance, 8 ether);
    }

    function test_RevertWhen_WithdrawingMoreThanDeposited() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        wallet.depositEth{value: 1 ether}();

        vm.prank(user);
        vm.expectRevert(bytes("Insufficient ETH balance"));
        wallet.withdrawEth(2 ether);
    }

    function test_DepositAndWithdrawErc20() public {
        token.transfer(user, 1000 ether);

        vm.prank(user);
        token.approve(address(wallet), 1000 ether);

        vm.prank(user);
        wallet.depositErc20(address(token), 500 ether);

        vm.prank(user);
        assertEq(wallet.getErc20Balance(address(token)), 500 ether);

        vm.prank(user);
        wallet.withdrawErc20(address(token), 200 ether);

        vm.prank(user);
        assertEq(wallet.getErc20Balance(address(token)), 300 ether);
        assertEq(token.balanceOf(user), 700 ether);
    }

    function test_ReceiveTriggersDepositEth() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        (bool ok,) = address(wallet).call{value: 1 ether}("");
        assertTrue(ok);

        vm.prank(user);
        assertEq(wallet.getEthBalance(), 1 ether);
    }
}
