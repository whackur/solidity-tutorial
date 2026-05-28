// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice "King of the Hill" with the classic push-payment DoS shape.
///         The contract requires a pushed refund to succeed before moving
///         to the next king.
contract Q14KingOfHill {
    address public currentKing;
    uint256 public currentBid;

    event NewKing(address indexed king, uint256 bid);

    function bid() external payable {
        require(msg.value > currentBid, "bid too low");
        // Push refund success is part of the state transition.
        if (currentKing != address(0)) {
            (bool ok,) = currentKing.call{value: currentBid}("");
            require(ok, "refund failed");
        }
        currentKing = msg.sender;
        currentBid = msg.value;
        emit NewKing(msg.sender, msg.value);
    }

    receive() external payable {}
}

/// @notice Per-user participant contract that refuses every refund.
contract Q14RevertKing {
    Q14KingOfHill public immutable target;
    address public immutable owner;

    error AlwaysReverts();

    constructor(Q14KingOfHill t, address o) {
        target = t;
        owner = o;
    }

    function takeThrone() external payable {
        require(msg.sender == owner, "only owner");
        target.bid{value: msg.value}();
    }

    receive() external payable {
        revert AlwaysReverts();
    }

    fallback() external payable {
        revert AlwaysReverts();
    }
}

/// @notice Multi-tenant DoS lab. Each user gets a personal (king-of-hill,
///         participant) pair via `createInstance()`.
contract Q14DosLab is SolvableBase {
    struct Instance {
        Q14KingOfHill king;
        Q14RevertKing attacker;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address king, address attacker);

    function createInstance() external returns (address kingAddr, address attackerAddr) {
        require(address(_instances[msg.sender].king) == address(0), "already created");

        Q14KingOfHill k = new Q14KingOfHill();
        Q14RevertKing a = new Q14RevertKing(k, msg.sender);

        _instances[msg.sender] = Instance(k, a);
        emit InstanceCreated(msg.sender, address(k), address(a));
        return (address(k), address(a));
    }

    function kingOf(address user) external view returns (Q14KingOfHill) {
        return _instances[user].king;
    }

    function attackerOf(address user) external view returns (Q14RevertKing) {
        return _instances[user].attacker;
    }

    /// @notice Solved when the user's reverting participant sits on the throne.
    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.king) == address(0)) return false;
        return inst.king.currentKing() == address(inst.attacker);
    }
}
