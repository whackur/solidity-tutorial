// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {DelegateCaller, DelegateLogic} from "../src/Setup.sol";

contract SolutionRef {
    function runCall(DelegateCaller dc, DelegateLogic dl, uint256 num) external payable {
        dc.setVarsViaCall{value: msg.value}(dl, num);
    }

    function runDelegatecall(DelegateCaller dc, address dl, uint256 num) external payable {
        dc.setVarsViaDelegatecall{value: msg.value}(dl, num);
    }

    receive() external payable {}
}
