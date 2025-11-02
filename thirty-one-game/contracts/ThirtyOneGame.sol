// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ThirtyOneGame
 * @dev A simple Baskin-Robbins 31 game where players contribute ERC20 tokens to participate.
 * The player who makes the index reach 31 or more wins the entire prize pool.
 */
contract ThirtyOneGame {
    // The ERC20 token used for betting
    IERC20 public immutable token;

    // 현재 게임의 숫자를 저장하는 변수 (0부터 시작)
    uint256 public currentIndex;

    // 게임의 승자 주소를 저장하는 변수
    address public winner;

    // 게임이 종료되었는지 여부를 나타내는 변수
    bool public gameOver;

    // 게임 참가를 위해 지불해야 하는 토큰 금액 (10 tokens)
    uint256 public constant TICKET_PRICE = 10 * 10**18;

    // 플레이어가 숫자를 성공적으로 제출했을 때 발생하는 이벤트
    event NumberSubmitted(address indexed player, uint256 number, uint256 newIndex);

    // 게임이 종료되고 승자가 결정되었을 때 발생하는 이벤트
    event GameEnd(address indexed winner, uint256 finalIndex, uint256 prizeAmount);

    /**
     * @dev 컨트랙트 배포 시 ERC20 토큰 주소를 설정합니다.
     * @param _token The address of the ERC20 token contract.
     */
    constructor(address _token) {
        token = IERC20(_token);
        currentIndex = 0;
        gameOver = false;
    }

    /**
     * @dev 사용자가 1~3 사이의 숫자를 제출하여 게임에 참여하는 함수입니다.
     * @param _number 제출할 숫자 (1, 2, 또는 3).
     */
    function submit(uint256 _number) public {
        // 1. 게임이 이미 종료되었는지 확인
        require(!gameOver, "Game is already over.");

        // 2. 제출하는 숫자가 1, 2, 3 중 하나인지 확인
        require(_number >= 1 && _number <= 3, "You can only submit numbers 1, 2, or 3.");

        // 3. 토큰 전송
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= TICKET_PRICE, "Check the token allowance");
        token.transferFrom(msg.sender, address(this), TICKET_PRICE);

        // 현재 인덱스에 제출된 숫자를 더함
        currentIndex += _number;

        // NumberSubmitted 이벤트 발생
        emit NumberSubmitted(msg.sender, _number, currentIndex);

        // 4. 인덱스가 31 이상이 되었는지 확인하여 승리 조건 체크
        if (currentIndex >= 31) {
            // 게임 상태 업데이트
            winner = msg.sender;
            gameOver = true;
            uint256 prizeAmount = token.balanceOf(address(this));

            // GameEnd 이벤트 발생
            emit GameEnd(winner, currentIndex, prizeAmount);

            // 컨트랙트의 모든 잔액을 승자에게 전송
            token.transfer(winner, prizeAmount);
        }
    }

    /**
     * @dev 컨트랙트의 현재 잔액을 확인하는 함수입니다.
     * @return 컨트랙트가 보유한 토큰의 총량.
     */
    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}