// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
import {EventsAndErrors} from "../src/Setup.sol";

contract SolutionRef {
    function knownSelectors()
        external
        pure
        returns (bytes4 errorStringSel, bytes4 panicSel, bytes4 customSel)
    {
        errorStringSel = bytes4(keccak256("Error(string)"));
        panicSel = bytes4(keccak256("Panic(uint256)"));
        customSel = bytes4(keccak256("InsufficientBalance(uint256,uint256)"));
    }

    function classify(EventsAndErrors e, uint8 kind) external returns (uint8 label) {
        if (kind == 0) {
            try e.failWithRequire(0) {} catch Error(string memory) {
                return 0;
            } catch {
                return 3;
            }
        } else if (kind == 1) {
            try e.failWithAssert(false) {} catch Panic(uint256) {
                return 1;
            } catch {
                return 3;
            }
        } else if (kind == 2) {
            try e.failWithCustomError(0, 1) {}
            catch (bytes memory reason) {
                if (bytes4(reason) == EventsAndErrors.InsufficientBalance.selector) {
                    return 2;
                }
                return 3;
            }
        }
        return 3;
    }
}
