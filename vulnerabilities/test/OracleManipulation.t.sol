// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

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

        // Within the same tx, move pool reserves sharply and read maxBorrow right after the spot price changes.
        // This sample demonstrates price instability; production protocols need a threat model for the market side they trust.
        pool.swapAforB(1_000 ether);
        uint256 manipulated = vuln.maxBorrow(1 ether);

        // Assert that the price changed *significantly* (at least 10%)
        uint256 diff = fairBefore > manipulated ? fairBefore - manipulated : manipulated - fairBefore;
        assertGt(diff * 10, fairBefore, "price should swing >10% in the same tx");
    }

    function test_SafeLendingIsStableWithinTx() public {
        uint256 before = safe.maxBorrow(1 ether);

        // SafeLending trusts only the separate oracle, so pool reserve movement does not affect this read.
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
