// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title MockPool — simplified *x*y=k* AMM pool
/// @notice Within a single transaction, swap → priceOfA() can be called, so the spot price becomes *temporarily distorted*
contract MockPool {
    uint256 public reserveA; // virtual balance of the base token
    uint256 public reserveB; // virtual balance of the quote token

    constructor(uint256 a, uint256 b) {
        reserveA = a;
        reserveB = b;
    }

    /// @return how many units of B correspond to 1 unit of A (1e18 scaled)
    function priceOfA() external view returns (uint256) {
        return reserveB * 1e18 / reserveA;
    }

    /// @notice Deposit A and receive B — preserves the *constant product K=A*B*
    function swapAforB(uint256 amountIn) external returns (uint256 amountOut) {
        uint256 k = reserveA * reserveB;
        reserveA += amountIn;
        amountOut = reserveB - k / reserveA;
        reserveB -= amountOut;
    }
}
