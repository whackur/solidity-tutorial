// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q15FrontRunLab, Q15FrontRunChallenge} from "../src/Setup.sol";

contract Q15FrontRunTest is Test {
    Q15FrontRunLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q15FrontRunLab();
        vm.deal(address(lab), 100 ether);
    }

    function _readSecret(Q15FrontRunChallenge c) internal view returns (bytes32) {
        // The student would call eth_getStorageAt off-chain. In tests we
        // use the equivalent vm.load cheatcode.
        return vm.load(address(c), bytes32(c.secretSlot()));
    }

    function _solve(address user) internal {
        vm.prank(user);
        lab.createInstance();
        Q15FrontRunChallenge c = lab.challengeOf(user);

        bytes32 secret = _readSecret(c);

        vm.prank(user);
        c.claim(secret);
    }

    function test_AliceSolves() public {
        uint256 aliceBefore = alice.balance;
        _solve(alice);
        Q15FrontRunChallenge c = lab.challengeOf(alice);
        assertEq(c.winner(), alice);
        assertEq(alice.balance, aliceBefore + 1 ether, "prize sent to winner");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));

        Q15FrontRunChallenge ac = lab.challengeOf(alice);
        Q15FrontRunChallenge bc = lab.challengeOf(bob);
        assertTrue(ac != bc, "different instances");
        // Each user's secret is distinct (different nonce / timestamp).
        assertTrue(_readSecret(ac) != _readSecret(bc));
    }

    function test_WrongGuessReverts() public {
        vm.prank(alice);
        lab.createInstance();
        Q15FrontRunChallenge c = lab.challengeOf(alice);

        vm.prank(alice);
        vm.expectRevert(bytes("wrong"));
        c.claim(bytes32(uint256(0xdeadbeef)));
    }

    function test_DoubleClaimReverts() public {
        _solve(alice);
        Q15FrontRunChallenge c = lab.challengeOf(alice);
        bytes32 secret = _readSecret(c);

        vm.prank(bob);
        vm.expectRevert(bytes("already claimed"));
        c.claim(secret);
    }

    /// @notice Demonstrate the "front-run" shape: a third party who
    ///         reads Alice's storage can claim Alice's prize before her.
    function test_ThirdPartyCanFrontRun() public {
        vm.prank(alice);
        lab.createInstance();
        Q15FrontRunChallenge c = lab.challengeOf(alice);

        bytes32 secret = _readSecret(c);

        // Bob front-runs.
        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        c.claim(secret);

        assertEq(c.winner(), bob);
        assertEq(bob.balance, bobBefore + 1 ether);
        assertFalse(lab.isSolved(alice), "alice loses to front-runner");
    }
}
