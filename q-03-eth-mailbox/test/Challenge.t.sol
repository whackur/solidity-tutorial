// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {EthMailbox} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q03MailboxTest is Test {
    EthMailbox internal mb;
    Solution internal sol;

    function setUp() public {
        mb = new EthMailbox();
        sol = new Solution();
        vm.deal(address(this), 10 ether);
    }

    function test_TriggerReceive() public {
        sol.triggerReceive{value: 1 ether}(mb);
        assertEq(uint8(mb.lastTrigger()), uint8(EthMailbox.Trigger.Receive), "trigger Receive");
        assertEq(mb.lastValue(), 1 ether, "value forwarded");
    }

    function test_TriggerFallback() public {
        bytes32 tag = bytes32(uint256(0xCAFEBABE));
        sol.triggerFallbackWithTag{value: 1 ether}(mb, tag);
        assertEq(uint8(mb.lastTrigger()), uint8(EthMailbox.Trigger.Fallback), "trigger Fallback");
        assertEq(mb.lastTag(), tag, "tag decoded by fallback");
        assertEq(mb.lastValue(), 1 ether, "value forwarded");
    }

    function test_TriggerReceivePayable() public {
        bytes32 tag = bytes32(uint256(0x1234));
        sol.triggerReceivePayable{value: 2 ether}(mb, tag);
        assertEq(
            uint8(mb.lastTrigger()),
            uint8(EthMailbox.Trigger.ReceivePayable),
            "trigger ReceivePayable"
        );
        assertEq(mb.lastTag(), tag, "tag stored by named fn");
        assertEq(mb.lastValue(), 2 ether, "value forwarded");
    }
}
