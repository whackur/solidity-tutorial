// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title EventsAndErrors — showcase of all event and error variants in a single contract
/// @notice
///   1. Events  — 0~3 indexed args + anonymous
///   2. Errors  — require / revert / custom error / assert / auto-Panic
///   3. Selector exposure for try/catch dispatch (links to lecture chapter 1-3)
contract EventsAndErrors {
    // ---------------------------------------------------------------------
    // 1. EVENT showcase
    // ---------------------------------------------------------------------

    /// @dev 0 indexed — every argument lives in the data section. Only topic[0] is the signature.
    event NoIndexedEvent(uint256 a, uint256 b);

    /// @dev 1 indexed — `from` goes into topic[1] so off-chain filters can match on it.
    event OneIndexedEvent(address indexed from, uint256 amount);

    /// @dev 2 indexed — same shape as ERC-20 Transfer.
    event TwoIndexedEvent(address indexed from, address indexed to, uint256 amount);

    /// @dev 3 indexed — the maximum for non-anonymous events. topic[0] is reserved for the signature hash.
    event ThreeIndexedEvent(
        address indexed from, address indexed to, uint256 indexed id, uint256 amount
    );

    /// @dev anonymous — topic[0] does *not* hold a signature hash.
    ///      In exchange, up to 4 indexed arguments are allowed and gas drops from LOG3 to LOG4 cost.
    ///      Downside: signature-based search no longer works — *not recommended for public contracts*.
    event AnonymousEvent(
        address indexed from, address indexed to, uint256 indexed id, uint256 indexed nonce
    ) anonymous;

    function emitAll(address from, address to, uint256 id, uint256 amount, uint256 nonce)
        external
    {
        emit NoIndexedEvent(amount, id);
        emit OneIndexedEvent(from, amount);
        emit TwoIndexedEvent(from, to, amount);
        emit ThreeIndexedEvent(from, to, id, amount);
        emit AnonymousEvent(from, to, id, nonce);
    }

    // ---------------------------------------------------------------------
    // 2. ERROR showcase — all four variants
    // ---------------------------------------------------------------------

    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized(address caller);

    /// @dev `require(cond, "msg")` → Error(string) selector 0x08c379a0
    function failWithRequire(uint256 v) external pure {
        require(v != 0, "value must be non-zero");
    }

    /// @dev `revert("msg")` → also Error(string)
    function failWithRevertString(uint256 v) external pure {
        if (v == 0) revert("value must be non-zero");
    }

    /// @dev custom error → caller decodes selector + ABI-encoded args. Cheap on gas.
    function failWithCustomError(uint256 available, uint256 required) external pure {
        if (available < required) revert InsufficientBalance(available, required);
    }

    /// @dev assert → Panic(0x01). Not for user-input validation. Reserved for *invariant* violations.
    function failWithAssert(bool cond) external pure {
        assert(cond);
    }

    /// @dev Triggers each Panic the compiler injects automatically — intentional failures for debugging.
    /// @param kind 1: assert, 17: arithmetic over/underflow, 18: division by zero,
    ///              50: array out-of-bounds
    function triggerAutoPanic(uint256 kind) external pure {
        if (kind == 1) {
            assert(false);
        } else if (kind == 17) {
            uint256 zero = 0;
            zero -= 1; // overflow → Panic(0x11)
        } else if (kind == 18) {
            uint256 zero = 0;
            uint256 q = uint256(1) / zero; // div0 → Panic(0x12)
            q;
        } else if (kind == 50) {
            uint256[] memory arr = new uint256[](1);
            arr[2]; // OOB → Panic(0x32)
        }
    }

    // ---------------------------------------------------------------------
    // 3. Selectors exposed directly — same lookup that try/catch dispatch uses
    // ---------------------------------------------------------------------

    /// @return The Error(string) selector — always 0x08c379a0
    function errorStringSelector() external pure returns (bytes4) {
        return bytes4(keccak256("Error(string)"));
    }

    /// @return The Panic(uint256) selector — always 0x4e487b71
    function panicSelector() external pure returns (bytes4) {
        return bytes4(keccak256("Panic(uint256)"));
    }

    /// @return The InsufficientBalance custom error selector
    function insufficientBalanceSelector() external pure returns (bytes4) {
        return InsufficientBalance.selector;
    }

    /// @return The TwoIndexedEvent topic[0] (signature hash)
    function twoIndexedTopic0() external pure returns (bytes32) {
        return keccak256("TwoIndexedEvent(address,address,uint256)");
    }
}
