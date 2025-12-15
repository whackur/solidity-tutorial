// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {CounterV1} from "./CounterV1.sol";

contract CounterV2 is CounterV1 {
    function decrement() public {
        count -= 1;
    }

    // Example of version string change or logic change
    function version() public pure returns (string memory) {
        return "v2";
    }
}
