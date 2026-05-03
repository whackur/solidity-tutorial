// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

import {EthSender, IEthMailbox} from "../src/EthSender.sol";
import {EthMailbox} from "../src/EthMailbox.sol";
import {EthSink} from "../src/EthSink.sol";
import {EthRejector} from "../src/EthRejector.sol";

contract EthSenderTest is Test {
    EthSender internal sender;
    EthMailbox internal mailbox;
    EthSink internal sink;
    EthRejector internal rejector;

    address internal user = makeAddr("user");

    function setUp() public {
        sender = new EthSender();
        mailbox = new EthMailbox();
        sink = new EthSink();
        rejector = new EthRejector();

        vm.deal(user, 100 ether);
        vm.deal(address(sender), 50 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       EOA → CONTRACT (direct receive)
    //////////////////////////////////////////////////////////////*/

    function test_externalDepositViaEmptyCalldataHitsReceive() public {
        uint256 prev = address(sender).balance;
        vm.prank(user);
        (bool ok,) = address(sender).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(sender).balance, prev + 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                CONTRACT BALANCE → EXTERNAL ADDRESS (4 paths)
    //////////////////////////////////////////////////////////////*/

    function test_sendViaTransferToSink() public {
        sender.sendViaTransfer(payable(address(sink)), 1 ether);
        assertEq(address(sink).balance, 1 ether);
    }

    function test_sendViaSendToSink() public {
        bool ok = sender.sendViaSend(payable(address(sink)), 1 ether);
        assertTrue(ok);
        assertEq(address(sink).balance, 1 ether);
    }

    function test_sendViaCallToMailbox() public {
        bool ok = sender.sendViaCall(payable(address(mailbox)), 1 ether);
        assertTrue(ok);
        assertEq(address(mailbox).balance, 1 ether);
        assertEq(uint256(mailbox.lastTrigger()), uint256(EthMailbox.Trigger.Receive));
        assertEq(mailbox.lastValue(), 1 ether);
    }

    function test_sendViaSendValueToSink() public {
        sender.sendViaSendValue(payable(address(sink)), 1 ether);
        assertEq(address(sink).balance, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       FAILURE MODES (transfer vs send)
    //////////////////////////////////////////////////////////////*/

    /// @dev Mailbox.receive writes storage, exhausting the 2300-gas stipend.
    function test_sendViaTransferRevertsOnStateWritingMailbox() public {
        vm.expectRevert();
        sender.sendViaTransfer(payable(address(mailbox)), 1 ether);
    }

    /// @dev `send` swallows the failure as `false` instead of reverting.
    function test_sendViaSendReturnsFalseOnStateWritingMailbox() public {
        bool ok = sender.sendViaSend(payable(address(mailbox)), 1 ether);
        assertFalse(ok);
        assertEq(address(mailbox).balance, 0);
    }

    function test_sendViaTransferRevertsOnRejector() public {
        vm.expectRevert();
        sender.sendViaTransfer(payable(address(rejector)), 1 ether);
    }

    function test_sendViaCallRevertsOnRejector() public {
        vm.expectRevert(bytes("call failed"));
        sender.sendViaCall(payable(address(rejector)), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
              INTERNAL-CALL COMPOSITION (single-tx multi-step)
    //////////////////////////////////////////////////////////////*/

    function test_sendAfterFeeRetainsFeeAndForwardsNet() public {
        uint256 senderStart = address(sender).balance;
        sender.sendAfterFee(payable(address(sink)), 10 ether, 500); // 5%
        assertEq(address(sink).balance, 9.5 ether);
        assertEq(address(sender).balance, senderStart - 9.5 ether);
    }

    /*//////////////////////////////////////////////////////////////
              CONTRACT → CONTRACT (interface vs raw call)
    //////////////////////////////////////////////////////////////*/

    function test_forwardToContractViaTypedInterface() public {
        sender.forwardToContract(IEthMailbox(address(mailbox)), 1 ether, bytes32("hello"));
        assertEq(uint256(mailbox.lastTrigger()), uint256(EthMailbox.Trigger.ReceivePayable));
        assertEq(mailbox.lastTag(), bytes32("hello"));
        assertEq(mailbox.lastValue(), 1 ether);
    }

    function test_forwardWithCallEmptyDataTriggersReceive() public {
        sender.forwardWithCall(payable(address(mailbox)), 1 ether, "");
        assertEq(uint256(mailbox.lastTrigger()), uint256(EthMailbox.Trigger.Receive));
    }

    function test_forwardWithCallUnknownSelectorTriggersFallback() public {
        bytes memory data = abi.encodePacked(bytes4(0xdeadbeef));
        sender.forwardWithCall(payable(address(mailbox)), 1 ether, data);
        assertEq(uint256(mailbox.lastTrigger()), uint256(EthMailbox.Trigger.Fallback));
        assertEq(keccak256(mailbox.lastCalldata()), keccak256(data));
    }

    function test_forwardWithCallNamedSelectorTriggersThatFunction() public {
        bytes memory data = abi.encodeCall(EthMailbox.receivePayable, (bytes32("named")));
        sender.forwardWithCall(payable(address(mailbox)), 1 ether, data);
        assertEq(uint256(mailbox.lastTrigger()), uint256(EthMailbox.Trigger.ReceivePayable));
        assertEq(mailbox.lastTag(), bytes32("named"));
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL (pull pattern)
    //////////////////////////////////////////////////////////////*/

    function test_withdrawDrainsBalanceToCaller() public {
        uint256 senderStart = address(sender).balance;
        uint256 userStart = user.balance;

        vm.prank(user);
        sender.withdraw();

        assertEq(address(sender).balance, 0);
        assertEq(user.balance, userStart + senderStart);
    }
}
