// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q21EcrecoverBasicLab} from "../src/Setup.sol";

contract Q21EcrecoverBasicTest is Test {
    Q21EcrecoverBasicLab internal lab;

    address internal trustedSigner;
    uint256 internal trustedSignerPk;

    address internal impostorA;
    uint256 internal impostorAPk;
    address internal impostorB;
    uint256 internal impostorBPk;

    uint256 internal correctIndex;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        (trustedSigner, trustedSignerPk) = makeAddrAndKey("trustedSigner");
        (impostorA, impostorAPk) = makeAddrAndKey("impostorA");
        (impostorB, impostorBPk) = makeAddrAndKey("impostorB");

        // Build three deterministic candidates. Pick a fixed index for the
        // correct one so the tests document the layout.
        Q21EcrecoverBasicLab.Candidate[] memory cands = new Q21EcrecoverBasicLab.Candidate[](3);
        cands[0] = _sign(impostorAPk, keccak256("hello from imposter A"));
        cands[1] = _sign(trustedSignerPk, keccak256("trusted signer authorized this message"));
        cands[2] = _sign(impostorBPk, keccak256("hello from imposter B"));
        correctIndex = 1;

        lab = new Q21EcrecoverBasicLab(trustedSigner, cands);
    }

    function _sign(uint256 pk, bytes32 hash) internal pure returns (Q21EcrecoverBasicLab.Candidate memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return Q21EcrecoverBasicLab.Candidate({messageHash: hash, v: v, r: r, s: s});
    }

    function test_AliceSubmitsCorrectIndex() public {
        vm.prank(alice);
        lab.submit(correctIndex);

        assertTrue(lab.isSolved(alice));
        assertEq(lab.submittedIndex(alice), correctIndex);
    }

    function test_TwoUsersIndependent() public {
        vm.prank(alice);
        lab.submit(correctIndex);

        vm.prank(bob);
        lab.submit(correctIndex);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));
        assertEq(lab.submittedIndex(alice), correctIndex);
        assertEq(lab.submittedIndex(bob), correctIndex);
    }

    function test_WrongIndexReverts() public {
        vm.prank(alice);
        vm.expectRevert(); // WrongSigner(recovered)
        lab.submit(0);

        assertFalse(lab.isSolved(alice));
    }

    function test_OutOfRangeReverts() public {
        vm.prank(alice);
        vm.expectRevert(Q21EcrecoverBasicLab.InvalidIndex.selector);
        lab.submit(99);
    }

    function test_AnyoneCanReadCandidates() public view {
        (bytes32 hash, uint8 v, bytes32 r, bytes32 s) = lab.candidate(correctIndex);
        // Anyone — including the test or a web UI — can recover the signer.
        address recovered = ecrecover(hash, v, r, s);
        assertEq(recovered, trustedSigner);
    }

    function test_OneUserSolvingDoesNotAffectAnother() public {
        vm.prank(alice);
        lab.submit(correctIndex);

        assertTrue(lab.isSolved(alice));
        assertFalse(lab.isSolved(bob));
    }
}
