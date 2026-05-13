// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {VulnerableSigClaim, IVulnerableSigClaim} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q10ReplayTest is Test {
    VulnerableSigClaim internal claim;
    Solution internal sol;

    address internal signer;
    uint256 internal signerPk;

    function setUp() public {
        (signer, signerPk) = makeAddrAndKey("signer");
        claim = new VulnerableSigClaim(signer);
        sol = new Solution();

        vm.deal(address(claim), 5 ether);
    }

    function _signOnce(address to, uint256 amount) internal view returns (bytes memory) {
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function test_ReplayFiveTimes() public {
        bytes memory sig = _signOnce(address(sol), 1 ether);
        sol.replay(IVulnerableSigClaim(address(claim)), payable(address(sol)), 1 ether, sig, 5);

        assertEq(address(claim).balance, 0, "claim drained");
        assertEq(address(sol).balance, 5 ether, "attacker keeps 5 ether");
    }
}
