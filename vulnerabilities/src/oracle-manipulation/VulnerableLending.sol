// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

interface IPool {
    function priceOfA() external view returns (uint256);
}

/// @title VulnerableLending — uses a *single pool's spot price* directly as the oracle
/// @notice Attacker: within the same tx
///   1) perform a large swap in the pool → reserveA surges, reserveB drops → priceOfA() collapses
///   2) use the same priceOfA() to calculate *inflated collateral value* → borrow more
///   ※ This example lending contract is *reversed* — the higher the price, the more you can borrow. The swap direction is flipped only for demonstration.
contract VulnerableLending {
    IPool public immutable pool;

    constructor(address p) {
        pool = IPool(p);
    }

    /// @notice maxBorrow per 1 unit of collateral — uses the pool's *spot price* (vulnerable)
    function maxBorrow(uint256 collateralA) external view returns (uint256) {
        uint256 price = pool.priceOfA(); // BAD: spot price
        return collateralA * price / 1e18;
    }
}
