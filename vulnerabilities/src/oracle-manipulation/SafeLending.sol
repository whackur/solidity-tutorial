// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title SafeLending — uses prices pushed by an *external oracle* (abstracted as TWAP / Chainlink, etc.)
/// @notice Does *not* read the spot price of a single pool directly — a separate trusted source updates over time
contract SafeLending {
    address public immutable oracle;
    uint256 public price; // 1e18 scaled — only the oracle can update it

    constructor(address o, uint256 initialPrice) {
        oracle = o;
        price = initialPrice;
    }

    function updatePrice(uint256 newPrice) external {
        require(msg.sender == oracle, "not oracle");
        price = newPrice;
    }

    function maxBorrow(uint256 collateralA) external view returns (uint256) {
        return collateralA * price / 1e18;
    }
}
