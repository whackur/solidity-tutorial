// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {ThirtyOneGame} from "../src/ThirtyOneGame.sol";
import {IThirtyOneGame} from "../src/interfaces/IThirtyOneGame.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract ThirtyOneGameTest is Test {
    ThirtyOneGame internal game;
    MockToken internal token;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant WINNER_PERCENTAGE = 80;

    function setUp() public {
        token = new MockToken();
        game = new ThirtyOneGame(address(token), WINNER_PERCENTAGE);

        token.transfer(alice, 10_000 ether);
        token.transfer(bob, 10_000 ether);

        vm.prank(alice);
        token.approve(address(game), type(uint256).max);
        vm.prank(bob);
        token.approve(address(game), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(address(game.token()), address(token));
        assertEq(game.currentRound(), 1);
        assertEq(game.winnerPercentage(), WINNER_PERCENTAGE);
    }

    function test_RevertWhen_InvalidWinnerPercentageOnConstruct() public {
        vm.expectRevert(bytes("Percentage must be between 1 and 100."));
        new ThirtyOneGame(address(token), 0);

        vm.expectRevert(bytes("Percentage must be between 1 and 100."));
        new ThirtyOneGame(address(token), 101);
    }

    function test_SubmitAdvancesIndexAndPool() public {
        vm.prank(alice);
        game.submit(1, 2, 20 ether);

        (uint256 idx, uint256 pool, bool over,) = game.getRoundInfo(1);
        assertEq(idx, 2);
        assertEq(pool, 20 ether);
        assertFalse(over);
    }

    function test_RevertWhen_NumberOutOfRange() public {
        vm.prank(alice);
        vm.expectRevert(bytes("You can only submit numbers 1, 2, or 3."));
        game.submit(1, 4, 20 ether);
    }

    function test_RevertWhen_AmountOutOfRange() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Amount must be between 10 and 50 tokens."));
        game.submit(1, 1, 9 ether);

        vm.prank(alice);
        vm.expectRevert(bytes("Amount must be between 10 and 50 tokens."));
        game.submit(1, 1, 51 ether);
    }

    function test_GameEndsAndDistributesPrize() public {
        // Push currentIndex to 30 with alice
        vm.startPrank(alice);
        for (uint256 i = 0; i < 10; i++) {
            game.submit(1, 3, 10 ether);
        }
        vm.stopPrank();

        (uint256 idx,, bool over,) = game.getRoundInfo(1);
        assertEq(idx, 30);
        assertFalse(over);

        // Bob submits 1 to push to 31 -> bob wins
        vm.prank(bob);
        game.submit(1, 1, 10 ether);

        (,, bool overAfter,) = game.getRoundInfo(1);
        assertTrue(overAfter);
        assertEq(game.winners(1), bob);

        // Total pool = 110 ether; bob's stake = 10 ether
        // Winner gets 80% of 110 = 88 ether
        // Remaining 22 ether distributed to losers (only alice has 100 ether stake) -> alice gets 22 ether
        assertEq(token.balanceOf(bob), 10_000 ether - 10 ether + 88 ether);
        assertEq(token.balanceOf(alice), 10_000 ether - 100 ether + 22 ether);
    }

    function test_StartNewRoundAfterGameOver() public {
        // End round 1
        vm.startPrank(alice);
        for (uint256 i = 0; i < 10; i++) {
            game.submit(1, 3, 10 ether);
        }
        vm.stopPrank();
        vm.prank(bob);
        game.submit(1, 1, 10 ether);

        game.startNewRound();
        assertEq(game.currentRound(), 2);

        (,, bool over, uint256 pct) = game.getRoundInfo(2);
        assertFalse(over);
        assertEq(pct, WINNER_PERCENTAGE);
    }

    function test_OwnerCanUpdateWinnerPercentage() public {
        game.setWinnerPercentage(50);
        assertEq(game.winnerPercentage(), 50);
    }

    function test_RevertWhen_NonOwnerSetsWinnerPercentage() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Only owner can call this function."));
        game.setWinnerPercentage(50);
    }
}
