// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {EventsAndErrors} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q02EventsErrorsTest is Test {
    EventsAndErrors internal e;
    Solution internal sol;

    function setUp() public {
        e = new EventsAndErrors();
        sol = new Solution();
    }

    function test_KnownSelectors() public view {
        (bytes4 errSel, bytes4 panicSel, bytes4 customSel) = sol.knownSelectors();
        assertEq(errSel, bytes4(0x08c379a0), "Error(string) selector");
        assertEq(panicSel, bytes4(0x4e487b71), "Panic(uint256) selector");
        assertEq(customSel, EventsAndErrors.InsufficientBalance.selector, "custom selector");
    }

    function test_ClassifyError() public {
        assertEq(sol.classify(e, 0), uint8(0), "require -> Error(string)");
    }

    function test_ClassifyPanic() public {
        assertEq(sol.classify(e, 1), uint8(1), "assert -> Panic(uint256)");
    }

    function test_ClassifyCustom() public {
        assertEq(sol.classify(e, 2), uint8(2), "revert MyErr -> custom");
    }
}
