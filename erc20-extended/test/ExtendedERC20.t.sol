// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {ExtendedERC20} from "../src/ExtendedERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract ExtendedERC20Test is Test {
    ExtendedERC20 internal token;

    address internal owner = address(this);
    uint256 internal alicePk = 0xA11CE;
    address internal alice;
    address internal bob = address(0xB0B);

    uint256 internal constant CAP = 1_000_000 ether;

    function setUp() public {
        alice = vm.addr(alicePk);
        token = new ExtendedERC20(owner, CAP);
    }

    // ----- Capped -----

    function test_MintRespectsCap() public {
        token.mint(alice, CAP);
        assertEq(token.totalSupply(), CAP);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP)
        );
        token.mint(alice, 1);
    }

    // ----- Burnable -----

    function test_BurnReducesSupply() public {
        token.mint(alice, 1_000);
        vm.prank(alice);
        token.burn(400);
        assertEq(token.balanceOf(alice), 600);
        assertEq(token.totalSupply(), 600);
    }

    // ----- Pausable -----

    function test_PauseBlocksTransfer() public {
        token.mint(alice, 1_000);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(bob, 100);

        token.unpause();
        vm.prank(alice);
        token.transfer(bob, 100);
        assertEq(token.balanceOf(bob), 100);
    }

    // ----- Votes (checkpoint) -----

    function test_VotesRequireDelegate() public {
        token.mint(alice, 1_000);
        // Voting power activates only after self-delegation (0 → 1000)
        assertEq(token.getVotes(alice), 0);
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 1_000);
    }

    function test_VotesPastSnapshot() public {
        // ERC20Votes default clock = block number → getPastVotes takes a block number
        token.mint(alice, 1_000);
        vm.prank(alice);
        token.delegate(alice);

        vm.roll(block.number + 1);
        uint256 snapshotBlock = block.number;

        // Mint more in a later block
        vm.roll(block.number + 1);
        token.mint(alice, 9_000);

        vm.roll(block.number + 1);
        // Past block's voting power is frozen at 1_000
        assertEq(token.getPastVotes(alice, snapshotBlock), 1_000);
        // Current voting power is 1_000 + 9_000
        assertEq(token.getVotes(alice), 10_000);
    }

    // ----- Permit (EIP-2612) -----

    function test_PermitAllowsGaslessApprove() public {
        token.mint(alice, 1_000);

        uint256 value = 500;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(alice);

        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, alice, bob, value, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        token.permit(alice, bob, value, deadline, v, r, s);
        assertEq(token.allowance(alice, bob), value);
        assertEq(token.nonces(alice), nonce + 1);
    }
}
