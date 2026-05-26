// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Per-user xy=k mock pool. No real ERC-20s are involved — only
///         the `reserveA` and `reserveB` numbers move. This lets a
///         student see *why* a single-pool spot price is a terrible
///         oracle: any trade against the pool changes the price.
contract MockPool {
    uint256 public reserveA;
    uint256 public reserveB;
    address public immutable owner;

    error OnlyOwner();
    error ZeroAmount();

    event Swap(address indexed by, uint256 amountInA, uint256 amountOutB, uint256 newReserveA, uint256 newReserveB);

    constructor(uint256 a, uint256 b, address o) {
        require(a > 0 && b > 0, "reserves=0");
        reserveA = a;
        reserveB = b;
        owner = o;
    }

    /// @notice xy=k swap of token A in for token B out. Pure bookkeeping
    ///         (no real tokens) so the student does not have to manage
    ///         approvals — the focus stays on the price math.
    function swapAForB(uint256 amountIn) external returns (uint256 amountOut) {
        if (msg.sender != owner) revert OnlyOwner();
        if (amountIn == 0) revert ZeroAmount();
        uint256 k = reserveA * reserveB;
        uint256 newReserveA = reserveA + amountIn;
        uint256 newReserveB = k / newReserveA;
        amountOut = reserveB - newReserveB;
        reserveA = newReserveA;
        reserveB = newReserveB;
        emit Swap(msg.sender, amountIn, amountOut, newReserveA, newReserveB);
    }

    /// @notice Spot price reported as `reserveB / reserveA` scaled by 1e18.
    function getSpotPriceE18() external view returns (uint256) {
        return (reserveB * 1e18) / reserveA;
    }
}

/// @notice Multi-tenant beginner spot-price lab. Each user gets their own
///         pool seeded with equal reserves so the starting spot price is
///         `1e18`. The goal is to swap enough of A in to drag the spot
///         price down to `TARGET_PRICE_E18` or below — i.e., to see that
///         a single trade can shift the "oracle".
contract SpotPriceBasicLab is SolvableBase {
    uint256 public constant INITIAL_RESERVE = 1_000e18;
    /// @dev Equivalent to "A is at least 2x more abundant than B". A
    ///      swap of ~414 A from the initial 1000:1000 pool reaches this.
    uint256 public constant TARGET_PRICE_E18 = 0.5e18;

    mapping(address => MockPool) public poolOf;

    event InstanceCreated(address indexed user, address pool);

    function createInstance() external returns (address pool) {
        require(address(poolOf[msg.sender]) == address(0), "already created");
        MockPool p = new MockPool(INITIAL_RESERVE, INITIAL_RESERVE, msg.sender);
        poolOf[msg.sender] = p;
        emit InstanceCreated(msg.sender, address(p));
        return address(p);
    }

    function isSolved(address user) public view override returns (bool) {
        MockPool p = poolOf[user];
        if (address(p) == address(0)) return false;
        return p.getSpotPriceE18() <= TARGET_PRICE_E18;
    }
}
