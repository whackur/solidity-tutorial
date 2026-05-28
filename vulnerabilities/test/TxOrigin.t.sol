// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {VulnerableWallet} from "../src/tx-origin/VulnerableWallet.sol";
import {SafeWallet} from "../src/tx-origin/SafeWallet.sol";
import {Phisher} from "../src/tx-origin/Phisher.sol";

contract TxOriginTest is Test {
    address internal victim = address(0xCAFE);
    address payable internal attacker = payable(address(0xBAD));

    function setUp() public {
        vm.deal(victim, 10 ether);
    }

    function test_VulnerableWalletIsPhished() public {
        // The victim deploys their wallet and funds it.
        //    NOTE: vm.prank(addr, addr) with two arguments changes both *msg.sender + tx.origin*
        vm.prank(victim, victim);
        VulnerableWallet wallet = new VulnerableWallet();
        vm.deal(address(wallet), 5 ether);

        // Another contract is deployed as an intermediate caller.
        vm.prank(attacker, attacker);
        Phisher phisher = new Phisher(address(wallet), 5 ether);

        // A social-engineering style call demonstrates why tx.origin is the wrong authorization primitive.
        vm.prank(victim, victim);
        phisher.claimAirdrop();

        assertEq(address(wallet).balance, 0);
        assertEq(attacker.balance, 5 ether);
    }

    function test_SafeWalletBlocksPhishing() public {
        vm.prank(victim, victim);
        SafeWallet wallet = new SafeWallet();
        vm.deal(address(wallet), 5 ether);

        // SafeWallet checks msg.sender == owner in transfer() → calls through an intermediate contract (Phisher) fail
        // A direct transfer call is also rejected because the phisher is not the owner
        vm.expectRevert(bytes("not owner"));
        vm.prank(attacker, attacker);
        wallet.transfer(attacker, 5 ether);

        assertEq(address(wallet).balance, 5 ether);
    }
}
