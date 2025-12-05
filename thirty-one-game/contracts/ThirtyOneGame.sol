// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IThirtyOneGame} from "./interfaces/IThirtyOneGame.sol";

/**
 * @title ThirtyOneGame
 * @dev A simple Baskin-Robbins 31 game with rounds and stake-based prize distribution.
 */
contract ThirtyOneGame is IThirtyOneGame {
    IERC20 public immutable override token;

    mapping(uint256 => Round) public override rounds;
    uint256 public override currentRound;
    mapping(uint256 => address) public override winners;
    uint256 public override winnerPercentage;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    constructor(address _token, uint256 _initialWinnerPercentage) {
        require(
            _initialWinnerPercentage > 0 && _initialWinnerPercentage <= 100, "Percentage must be between 1 and 100."
        );
        token = IERC20(_token);
        owner = msg.sender;
        currentRound = 1;
        winnerPercentage = _initialWinnerPercentage;
        rounds[currentRound].gameOver = false;
        rounds[currentRound].winnerPercentage = _initialWinnerPercentage;
    }

    function submit(uint256 _round, uint256 _number, uint256 _amount) public override {
        require(_round == currentRound, "This round is not active.");
        Round storage round = rounds[_round];
        require(!round.gameOver, "Game is already over.");
        require(_number >= 1 && _number <= 3, "You can only submit numbers 1, 2, or 3.");
        require(_amount >= 10 * 10 ** 18 && _amount <= 50 * 10 ** 18, "Amount must be between 10 and 50 tokens.");

        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");
        token.transferFrom(msg.sender, address(this), _amount);

        if (round.playerStakes[msg.sender] == 0) {
            round.players.push(Player(msg.sender, 0)); // amount will be updated below
        }

        round.playerStakes[msg.sender] += _amount;
        round.prizePool += _amount;
        round.currentIndex += _number;

        emit NumberSubmitted(_round, msg.sender, _number, round.currentIndex);

        if (round.currentIndex >= 31) {
            round.gameOver = true;
            winners[_round] = msg.sender;
            uint256 totalPrize = round.prizePool;

            emit GameEnd(_round, msg.sender, round.currentIndex, totalPrize);

            _distributePrizes(_round);
        }
    }

    function _distributePrizes(uint256 _round) internal {
        Round storage round = rounds[_round];
        address winner = winners[_round];
        uint256 totalPrize = round.prizePool;

        uint256 winnerPrize = (totalPrize * round.winnerPercentage) / 100;
        if (winnerPrize > 0) {
            token.transfer(winner, winnerPrize);
        }

        uint256 remainingPrize = totalPrize - winnerPrize;

        if (remainingPrize > 0 && round.players.length > 1) {
            uint256 totalStakeOfLosers = totalPrize - round.playerStakes[winner];

            if (totalStakeOfLosers > 0) {
                for (uint256 i = 0; i < round.players.length; i++) {
                    address playerAddress = round.players[i].playerAddress;
                    if (playerAddress != winner) {
                        uint256 playerStake = round.playerStakes[playerAddress];
                        uint256 share = (remainingPrize * playerStake) / totalStakeOfLosers;
                        if (share > 0) {
                            token.transfer(playerAddress, share);
                        }
                    }
                }
            }
        }
    }

    function startNewRound() public override {
        require(rounds[currentRound].gameOver, "Current round is not over yet.");
        currentRound++;
        Round storage newRound = rounds[currentRound];
        newRound.gameOver = false;
        newRound.winnerPercentage = winnerPercentage;
        newRound.currentIndex = 0;
        newRound.prizePool = 0;
    }

    function setWinnerPercentage(uint256 _newPercentage) public override onlyOwner {
        require(_newPercentage > 0 && _newPercentage <= 100, "Percentage must be between 1 and 100.");
        winnerPercentage = _newPercentage;
        emit WinnerPercentageUpdated(_newPercentage);
    }

    function getRoundInfo(uint256 _round) public view override returns (uint256, uint256, bool, uint256) {
        Round storage round = rounds[_round];
        return (round.currentIndex, round.prizePool, round.gameOver, round.winnerPercentage);
    }

    function getRoundPlayers(uint256 _round) public view override returns (Player[] memory) {
        Round storage round = rounds[_round];
        Player[] memory playersWithStakes = new Player[](round.players.length);
        for (uint256 i = 0; i < round.players.length; i++) {
            playersWithStakes[i].playerAddress = round.players[i].playerAddress;
            playersWithStakes[i].amount = round.playerStakes[round.players[i].playerAddress];
        }
        return playersWithStakes;
    }

    function getContractBalance() public view override returns (uint256) {
        return token.balanceOf(address(this));
    }
}
