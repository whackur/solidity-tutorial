// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ThirtyOneGame} from "../src/ThirtyOneGame.sol";
import {IThirtyOneGame} from "../src/interfaces/IThirtyOneGame.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MockAllowlist {
    mapping(address account => bool) internal allowed;

    function setAllowed(address account, bool value) external {
        allowed[account] = value;
    }

    function isAllowed(address account) external view returns (bool) {
        return allowed[account];
    }
}

contract InvalidAllowlist {}

contract ThirtyOneGameTest is Test {
    ThirtyOneGame internal game;
    MockToken internal token;
    MockAllowlist internal allowlist;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant WINNER_PERCENTAGE = 80;

    function setUp() public {
        token = new MockToken();
        allowlist = new MockAllowlist();
        game = new ThirtyOneGame(address(token), address(allowlist), WINNER_PERCENTAGE);

        allowlist.setAllowed(alice, true);
        allowlist.setAllowed(bob, true);

        token.transfer(alice, 10_000 ether);
        token.transfer(bob, 10_000 ether);

        vm.prank(alice);
        token.approve(address(game), type(uint256).max);
        vm.prank(bob);
        token.approve(address(game), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(address(game.token()), address(token));
        assertEq(address(game.allowlist()), address(allowlist));
        assertEq(game.currentRound(), 1);
        assertEq(game.winnerPercentage(), WINNER_PERCENTAGE);
    }

    function test_RevertWhen_InvalidWinnerPercentageOnConstruct() public {
        vm.expectRevert(bytes("Percentage must be between 1 and 100."));
        new ThirtyOneGame(address(token), address(allowlist), 0);

        vm.expectRevert(bytes("Percentage must be between 1 and 100."));
        new ThirtyOneGame(address(token), address(allowlist), 101);
    }

    function test_RevertWhen_AllowlistAddressIsZero() public {
        vm.expectRevert(bytes("Allowlist address cannot be zero."));
        new ThirtyOneGame(address(token), address(0), WINNER_PERCENTAGE);
    }

    function test_RevertWhen_AllowlistIsNotAContract() public {
        vm.expectRevert(bytes("Allowlist must be a contract."));
        new ThirtyOneGame(address(token), alice, WINNER_PERCENTAGE);
    }

    function test_RevertWhen_AllowlistContractHasNoInterface() public {
        InvalidAllowlist invalidAllowlist = new InvalidAllowlist();

        vm.expectRevert(bytes("Invalid allowlist contract."));
        new ThirtyOneGame(address(token), address(invalidAllowlist), WINNER_PERCENTAGE);
    }

    function test_RevertWhen_PlayerIsNotAllowlisted() public {
        allowlist.setAllowed(alice, false);

        vm.prank(alice);
        vm.expectRevert(bytes("Player is not allowlisted."));
        game.submit(1, 2, 20 ether);
    }

    function test_RevertAfter_PlayerIsRevoked() public {
        vm.prank(alice);
        game.submit(1, 2, 20 ether);

        allowlist.setAllowed(alice, false);

        vm.prank(alice);
        vm.expectRevert(bytes("Player is not allowlisted."));
        game.submit(1, 1, 10 ether);
    }

    function test_SubmitAdvancesIndexAndPool() public {
        vm.prank(alice);
        game.submit(1, 2, 20 ether);

        (uint256 idx, uint256 pool, bool over,) = game.getRoundInfo(1);
        assertEq(idx, 2);
        assertEq(pool, 20 ether);
        assertFalse(over);
        assertEq(game.lastSubmitter(1), alice);
    }

    function test_RevertWhen_SamePlayerSubmitsTwiceInARow() public {
        vm.startPrank(alice);
        game.submit(1, 2, 20 ether);
        vm.expectRevert(bytes("The same player cannot submit twice in a row."));
        game.submit(1, 1, 10 ether);
        vm.stopPrank();

        (uint256 idx, uint256 pool,,) = game.getRoundInfo(1);
        assertEq(idx, 2);
        assertEq(pool, 20 ether);
    }

    function test_AllowsAlternatingPlayers() public {
        vm.prank(alice);
        game.submit(1, 2, 20 ether);

        vm.prank(bob);
        game.submit(1, 3, 10 ether);

        (uint256 idx, uint256 pool,,) = game.getRoundInfo(1);
        assertEq(idx, 5);
        assertEq(pool, 30 ether);
        assertEq(game.lastSubmitter(1), bob);
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
        // Push currentIndex to 30 while alternating players.
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(i % 2 == 0 ? alice : bob);
            game.submit(1, 3, 10 ether);
        }

        (uint256 idx,, bool over,) = game.getRoundInfo(1);
        assertEq(idx, 30);
        assertFalse(over);

        // Alice submits 1 to push to 31 -> alice wins.
        vm.prank(alice);
        game.submit(1, 1, 10 ether);

        (,, bool overAfter,) = game.getRoundInfo(1);
        assertTrue(overAfter);
        assertEq(game.winners(1), alice);

        // Total pool = 110 ether; alice staked 60 and bob staked 50.
        // The winner receives 88 and the only loser receives the remaining 22.
        assertEq(token.balanceOf(alice), 10_000 ether - 60 ether + 88 ether);
        assertEq(token.balanceOf(bob), 10_000 ether - 50 ether + 22 ether);
    }

    function test_StartNewRoundAfterGameOver() public {
        // End round 1
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(i % 2 == 0 ? alice : bob);
            game.submit(1, 3, 10 ether);
        }
        vm.prank(alice);
        game.submit(1, 1, 10 ether);

        game.startNewRound();
        assertEq(game.currentRound(), 2);

        (,, bool over, uint256 pct) = game.getRoundInfo(2);
        assertFalse(over);
        assertEq(pct, WINNER_PERCENTAGE);
        assertEq(game.lastSubmitter(2), address(0));
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
