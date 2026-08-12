// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleDistributor} from "../src/MerkleDistributor.sol";
import {MerkleTreeLib} from "./MerkleTreeLib.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

/// @notice A token that refuses transfers to a blocked address, the way a
///         compliance-gated token refuses a holder who fell out of the
///         allowlist. Used to show why pull beats push here.
contract BlockingToken is ERC20 {
    address public blocked;

    constructor() ERC20("Block", "BLK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function setBlocked(address account) external {
        blocked = account;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(to != blocked, "RECIPIENT_NOT_ALLOWED");
        return super.transfer(to, value);
    }
}

contract MerkleDistributorTest is Test {
    using MerkleTreeLib for bytes32[];

    MockToken internal token;
    MerkleDistributor internal distributor;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant ALICE_AMOUNT = 100 ether;
    uint256 internal constant BOB_AMOUNT = 250 ether;
    uint256 internal constant CAROL_AMOUNT = 75 ether;
    uint256 internal constant TOTAL = ALICE_AMOUNT + BOB_AMOUNT + CAROL_AMOUNT;

    bytes32[] internal leaves;

    function setUp() public {
        token = new MockToken();

        leaves.push(_leaf(0, alice, ALICE_AMOUNT));
        leaves.push(_leaf(1, bob, BOB_AMOUNT));
        leaves.push(_leaf(2, carol, CAROL_AMOUNT));

        distributor = new MerkleDistributor(IERC20(address(token)), leaves.root());
        token.transfer(address(distributor), TOTAL);
    }

    function _leaf(uint256 index, address account, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
    }

    // --- claiming ---------------------------------------------------------

    function test_ValidClaimPaysTheRightAccount() public {
        vm.prank(alice);
        distributor.claim(0, alice, ALICE_AMOUNT, leaves.proof(0));

        assertEq(token.balanceOf(alice), ALICE_AMOUNT);
        assertTrue(distributor.isClaimed(0));
    }

    function test_EveryAllocationClaimable() public {
        distributor.claim(0, alice, ALICE_AMOUNT, leaves.proof(0));
        distributor.claim(1, bob, BOB_AMOUNT, leaves.proof(1));
        distributor.claim(2, carol, CAROL_AMOUNT, leaves.proof(2));

        assertEq(token.balanceOf(alice), ALICE_AMOUNT);
        assertEq(token.balanceOf(bob), BOB_AMOUNT);
        assertEq(token.balanceOf(carol), CAROL_AMOUNT);
        assertEq(token.balanceOf(address(distributor)), 0, "distributor fully drained");
    }

    /// @dev Anyone may submit the proof; the funds still land on `account`.
    function test_ThirdPartyCanSubmitAndFundsStillGoToAccount() public {
        vm.prank(stranger);
        distributor.claim(0, alice, ALICE_AMOUNT, leaves.proof(0));

        assertEq(token.balanceOf(alice), ALICE_AMOUNT);
        assertEq(token.balanceOf(stranger), 0, "submitter receives nothing");
    }

    function test_RevertWhen_ClaimingTwice() public {
        distributor.claim(0, alice, ALICE_AMOUNT, leaves.proof(0));

        vm.expectRevert(MerkleDistributor.AlreadyClaimed.selector);
        distributor.claim(0, alice, ALICE_AMOUNT, leaves.proof(0));
    }

    function test_RevertWhen_AmountTampered() public {
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(0, alice, ALICE_AMOUNT + 1, leaves.proof(0));
    }

    function test_RevertWhen_AccountSwapped() public {
        // Alice's proof, but redirected to Bob.
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(0, bob, ALICE_AMOUNT, leaves.proof(0));
    }

    function test_RevertWhen_IndexSwapped() public {
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(1, alice, ALICE_AMOUNT, leaves.proof(0));
    }

    // --- bitmap -----------------------------------------------------------

    function test_BitmapSpansMultipleWords() public {
        // Indices 0 and 300 land in different 256-bit words.
        bytes32[] memory wide = new bytes32[](2);
        wide[0] = _leaf(0, alice, ALICE_AMOUNT);
        wide[1] = _leaf(300, bob, BOB_AMOUNT);

        MerkleDistributor d = new MerkleDistributor(IERC20(address(token)), MerkleTreeLib.root(wide));
        token.transfer(address(d), ALICE_AMOUNT + BOB_AMOUNT);

        assertFalse(d.isClaimed(0));
        assertFalse(d.isClaimed(300));

        d.claim(0, alice, ALICE_AMOUNT, MerkleTreeLib.proof(wide, 0));
        assertTrue(d.isClaimed(0));
        assertFalse(d.isClaimed(300), "claiming word 0 must not mark word 1");

        d.claim(300, bob, BOB_AMOUNT, MerkleTreeLib.proof(wide, 1));
        assertTrue(d.isClaimed(300));
    }

    // --- why pull, not push ----------------------------------------------

    /// @dev One blocked recipient stops only their own claim. The others are
    ///      untouched, and the unclaimed amount stays visible on-chain.
    function test_BlockedRecipientDoesNotStopOthers() public {
        BlockingToken blocking = new BlockingToken();

        bytes32[] memory set = new bytes32[](2);
        set[0] = _leaf(0, alice, ALICE_AMOUNT);
        set[1] = _leaf(1, bob, BOB_AMOUNT);

        MerkleDistributor d = new MerkleDistributor(IERC20(address(blocking)), MerkleTreeLib.root(set));
        blocking.transfer(address(d), ALICE_AMOUNT + BOB_AMOUNT);

        blocking.setBlocked(alice);

        vm.expectRevert(bytes("RECIPIENT_NOT_ALLOWED"));
        d.claim(0, alice, ALICE_AMOUNT, MerkleTreeLib.proof(set, 0));

        // Bob is unaffected.
        d.claim(1, bob, BOB_AMOUNT, MerkleTreeLib.proof(set, 1));
        assertEq(blocking.balanceOf(bob), BOB_AMOUNT);

        // Alice's allocation is still unclaimed and still sitting here.
        assertFalse(d.isClaimed(0));
        assertEq(blocking.balanceOf(address(d)), ALICE_AMOUNT);
    }
}
