// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

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
        // 1) The victim deploys their wallet + deposits funds
        //    NOTE: vm.prank(addr, addr) with two arguments changes both *msg.sender + tx.origin*
        vm.prank(victim, victim);
        VulnerableWallet wallet = new VulnerableWallet();
        vm.deal(address(wallet), 5 ether);

        // 2) The attacker deploys the phisher contract (targeting the victim's wallet)
        vm.prank(attacker, attacker);
        Phisher phisher = new Phisher(address(wallet), 5 ether);

        // 3) The victim calls phisher.claimAirdrop() (a social-engineering scenario)
        //    → inside wallet.transfer, tx.origin == victim so it passes → 5 ETH goes to the attacker
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
