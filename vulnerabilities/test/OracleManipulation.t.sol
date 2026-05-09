// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockPool} from "../src/oracle-manipulation/MockPool.sol";
import {VulnerableLending} from "../src/oracle-manipulation/VulnerableLending.sol";
import {SafeLending} from "../src/oracle-manipulation/SafeLending.sol";

contract OracleManipulationTest is Test {
    MockPool internal pool;
    VulnerableLending internal vuln;
    SafeLending internal safe;
    address internal oracle = address(0xFEED);

    function setUp() public {
        // 100 A : 100_000 B → 1A = 1000B (1e18 scaled = 1000e18)
        pool = new MockPool(100 ether, 100_000 ether);
        vuln = new VulnerableLending(address(pool));
        safe = new SafeLending(oracle, 1_000 ether);
    }

    function test_VulnerableLendingIsManipulated() public {
        uint256 fairBefore = vuln.maxBorrow(1 ether);

        // Attacker: within the same tx, perform a large swap in the pool and then read maxBorrow right after the price swings
        // Adding 1000 A causes reserveA to surge → priceOfA() *plummets*
        // To borrow more in the *opposite direction*, combine the swap direction and lending model when constructing the scenario.
        // Here we only demonstrate that the *price itself swings* — the key point is that the two results differ greatly within the same tx.
        pool.swapAforB(1_000 ether);
        uint256 manipulated = vuln.maxBorrow(1 ether);

        // Assert that the price changed *significantly* (at least 10%)
        uint256 diff = fairBefore > manipulated ? fairBefore - manipulated : manipulated - fairBefore;
        assertGt(diff * 10, fairBefore, "price should swing >10% in the same tx");
    }

    function test_SafeLendingIsStableWithinTx() public {
        uint256 before = safe.maxBorrow(1 ether);

        // Even if the pool price moves within the same tx, SafeLending trusts only the *separate oracle* → no impact
        pool.swapAforB(1_000 ether);
        uint256 after_ = safe.maxBorrow(1 ether);
        assertEq(before, after_);
    }

    function test_SafeLendingOnlyOracleCanUpdate() public {
        vm.expectRevert(bytes("not oracle"));
        safe.updatePrice(2_000 ether);

        vm.prank(oracle);
        safe.updatePrice(2_000 ether);
        assertEq(safe.maxBorrow(1 ether), 2_000 ether);
    }
}
