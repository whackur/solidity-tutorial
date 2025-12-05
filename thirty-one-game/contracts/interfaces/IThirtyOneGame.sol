// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IThirtyOneGame {
    struct Player {
        address playerAddress;
        uint256 amount;
    }

    struct Round {
        uint256 currentIndex;
        uint256 prizePool;
        bool gameOver;
        Player[] players;
        mapping(address => uint256) playerStakes;
        uint256 winnerPercentage; // Winner's percentage for this round
    }

    event NumberSubmitted(uint256 indexed round, address indexed player, uint256 number, uint256 newIndex);
    event GameEnd(uint256 indexed round, address indexed winner, uint256 finalIndex, uint256 prizeAmount);
    event WinnerPercentageUpdated(uint256 newPercentage);

    function token() external view returns (IERC20);

    function rounds(uint256 _round)
        external
        view
        returns (uint256 currentIndex, uint256 prizePool, bool gameOver, uint256 winnerPercentage);

    function currentRound() external view returns (uint256);

    function winners(uint256 _round) external view returns (address);

    function winnerPercentage() external view returns (uint256);

    function submit(uint256 _round, uint256 _number, uint256 _amount) external;

    function startNewRound() external;

    function setWinnerPercentage(uint256 _newPercentage) external;

    function getRoundInfo(uint256 _round) external view returns (uint256, uint256, bool, uint256);

    function getRoundPlayers(uint256 _round) external view returns (Player[] memory);

    function getContractBalance() external view returns (uint256);
}
