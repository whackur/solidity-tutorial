// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice V1 implementation behind each user's proxy. Has increment() only.
///         _authorizeUpgrade is gated by onlyOwner, so only the proxy owner
///         (the student) can upgrade.
contract Q25CounterV1 is Initializable, UUPSUpgradeable {
    uint256 public count;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        owner = initialOwner;
    }

    function increment() public {
        count += 1;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

/// @notice V2 implementation. Adds version() — its existence is how the lab
///         detects that a proxy has been upgraded. Inherits V1's storage
///         layout (count, owner) so the upgrade is storage-compatible.
contract Q25CounterV2 is Q25CounterV1 {
    function decrement() public {
        count -= 1;
    }

    function version() public pure returns (string memory) {
        return "v2";
    }
}

/// @notice Multi-tenant UUPS lab. Every user calls createInstance() once to
///         get their own ERC1967 proxy pointing at Q25CounterV1, with themselves
///         as owner. The V1 and V2 implementations are deployed once and
///         shared.
///
///         Solve goal (per user):
///           1. createInstance() — your proxy starts on Q25CounterV1.
///           2. Q25CounterV1(proxy).upgradeToAndCall(v2Impl, "") — only you can,
///              because _authorizeUpgrade is onlyOwner.
///           After that version() exists on your proxy and isSolved flips true.
contract Q25UupsLab is SolvableBase {
    Q25CounterV1 public immutable v1Impl;
    Q25CounterV2 public immutable v2Impl;

    mapping(address => address) public proxyOf;

    event InstanceCreated(address indexed user, address proxy);

    constructor() {
        v1Impl = new Q25CounterV1();
        v2Impl = new Q25CounterV2();
    }

    function createInstance() external returns (address proxy) {
        require(proxyOf[msg.sender] == address(0), "already created");
        bytes memory initData = abi.encodeCall(Q25CounterV1.initialize, (msg.sender));
        ERC1967Proxy p = new ERC1967Proxy(address(v1Impl), initData);
        proxy = address(p);
        proxyOf[msg.sender] = proxy;
        emit InstanceCreated(msg.sender, proxy);
    }

    function isSolved(address user) public view override returns (bool) {
        address proxy = proxyOf[user];
        if (proxy == address(0)) return false;
        // version() only exists on V2 — a V1 proxy reverts and lands in catch.
        try Q25CounterV2(proxy).version() returns (string memory v) {
            return keccak256(bytes(v)) == keccak256(bytes("v2"));
        } catch {
            return false;
        }
    }
}
