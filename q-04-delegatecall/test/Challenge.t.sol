// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {DelegateCaller, DelegateLogic} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q04DelegatecallTest is Test {
    DelegateCaller internal dc;
    DelegateLogic internal dl;
    Solution internal sol;

    function setUp() public {
        dc = new DelegateCaller();
        dl = new DelegateLogic();
        sol = new Solution();
        vm.deal(address(this), 10 ether);
    }

    function test_CallChangesLogicNotCaller() public {
        sol.runCall{value: 1 ether}(dc, dl, 42);
        assertEq(dl.number(), 42, "logic.number must be 42");
        assertEq(dc.number(), 0, "caller.number must stay 0");
    }

    function test_DelegatecallChangesCallerNotLogic() public {
        sol.runDelegatecall{value: 1 ether}(dc, address(dl), 99);
        assertEq(dc.number(), 99, "caller.number must be 99");
        assertEq(dl.number(), 0, "logic.number must stay 0");
    }

    function test_SenderPreservedThroughDelegatecall() public {
        sol.runDelegatecall(dc, address(dl), 7);
        // delegatecall preserves msg.sender from the outer call (which was sol).
        assertEq(dc.sender(), address(sol), "msg.sender preserved through delegatecall");
    }
}
