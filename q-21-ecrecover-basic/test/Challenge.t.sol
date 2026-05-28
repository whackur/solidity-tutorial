// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q21EcrecoverBasicLab} from "../src/Setup.sol";

contract Q21EcrecoverBasicPublicTest is Test {
    Q21EcrecoverBasicLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        Q21EcrecoverBasicLab.Candidate[] memory candidates = new Q21EcrecoverBasicLab.Candidate[](1);
        lab = new Q21EcrecoverBasicLab(makeAddr("trustedSigner"), candidates);
    }

    function test_InitialStateIsUnsolved() public view {
        assertFalse(lab.isSolved(alice));
    }

    function test_InvalidIndexIsRejected() public {
        vm.prank(alice);
        vm.expectRevert(Q21EcrecoverBasicLab.InvalidIndex.selector);
        lab.submit(1);
    }
}
