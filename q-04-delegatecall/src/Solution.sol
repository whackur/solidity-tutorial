// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {DelegateCaller, DelegateLogic} from "./Setup.sol";

contract Solution {
    /// @notice Trigger a normal call — should mutate `dl` storage, not `dc`.
    function runCall(DelegateCaller dc, DelegateLogic dl, uint256 num) external payable {
        // TODO: dc.setVarsViaCall{value: msg.value}(dl, num);
        dc; dl; num;
        revert("Solution.runCall: not implemented");
    }

    /// @notice Trigger a delegatecall — should mutate `dc` storage, not `dl`.
    function runDelegatecall(DelegateCaller dc, address dl, uint256 num) external payable {
        // TODO: dc.setVarsViaDelegatecall{value: msg.value}(dl, num);
        dc; dl; num;
        revert("Solution.runDelegatecall: not implemented");
    }

    receive() external payable {}
}
