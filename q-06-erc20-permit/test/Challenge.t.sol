// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {PermitToken} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q06PermitTest is Test {
    PermitToken internal token;
    Solution internal sol;

    address internal owner;
    uint256 internal ownerPk;
    address internal recipient = address(0xBEEF);

    uint256 internal constant VALUE = 100e18;
    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("owner");
        token = new PermitToken();
        sol = new Solution();
        token.mint(owner, VALUE);
    }

    function _signPermit(uint256 nonce, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(sol), VALUE, nonce, deadline));
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        (v, r, s) = vm.sign(ownerPk, digest);
    }

    function test_PullWithPermit() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(token.nonces(owner), deadline);

        sol.pullWithPermit(IERC20Permit(address(token)), owner, VALUE, deadline, v, r, s, recipient);

        assertEq(token.balanceOf(recipient), VALUE, "recipient holds tokens");
        assertEq(token.balanceOf(owner), 0, "owner emptied");
    }

    function test_NonceConsumed() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(token.nonces(owner), deadline);

        // first consume succeeds
        sol.pullWithPermit(IERC20Permit(address(token)), owner, VALUE, deadline, v, r, s, recipient);

        // re-using the same signature must revert — nonce was consumed
        vm.expectRevert();
        sol.pullWithPermit(IERC20Permit(address(token)), owner, VALUE, deadline, v, r, s, recipient);
    }
}
