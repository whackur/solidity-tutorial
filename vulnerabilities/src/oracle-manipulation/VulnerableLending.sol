// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

interface IPool {
    function priceOfA() external view returns (uint256);
}

/// @title VulnerableLending — uses a *single pool's spot price* directly as the oracle
/// @notice Attacker: within the same tx
///   1) perform a large swap in the pool so reserves move sharply
///   2) read priceOfA() immediately after the spot price has moved
///   The test demonstrates spot-price instability; real lending systems must also model which side of the market the protocol trusts.
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
