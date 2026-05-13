// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title ISmartAccount
///
/// @notice Minimal EIP-7702 smart account interface — sponsored ECDSA-verified
///         batch execution and direct owner batch execution.
///
/// @dev Single-owner model: the owner is always `address(this)` (the EOA under
///      EIP-7702 delegation). No session keys, no recovery, no proxy.
interface ISmartAccount {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Single call inside a batch.
    /// @param target The address to call.
    /// @param value  The native-asset value forwarded with the call.
    /// @param data   The raw calldata for the target.
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when ECDSA recovery fails or the recovered signer is not the owner.
    error InvalidSignature();

    /// @notice Thrown when a batch contains zero calls.
    error EmptyBatch();

    /// @notice Thrown when `validUntil` is zero.
    error ValidUntilZero();

    /// @notice Thrown when `block.timestamp` is below `validAfter`.
    error ValidAfterNotReached(uint48 validAfter, uint256 currentTime);

    /// @notice Thrown when `block.timestamp` exceeds `validUntil`.
    error ValidUntilExpired(uint48 validUntil, uint256 currentTime);

    /// @notice Thrown when a privileged function is called by something other than the owner.
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after sponsored execution succeeds.
    /// @param nonce     The nonce consumed by this execution.
    /// @param callsHash `keccak256(abi.encode(calls))` — same hash signed in the digest.
    /// @param callCount The number of calls in the batch.
    event BatchExecuted(uint256 indexed nonce, bytes32 indexed callsHash, uint256 callCount);

    /// @notice Emitted after a direct owner batch execution succeeds.
    event BatchDirectExecuted(address indexed executor, uint256 callCount);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a batch verified by an owner ECDSA signature (sponsored execution).
    ///
    /// @dev Anyone may submit this transaction — the signature proves the EOA owner authorized
    ///      the calls. Nonce is consumed for replay protection. Chain id and contract address
    ///      are bound via the EIP-712 domain separator.
    ///
    /// @param calls      The batch of calls to execute.
    /// @param validAfter Earliest timestamp at which the signature is valid. 0 = immediately valid.
    /// @param validUntil Latest timestamp at which the signature remains valid. Must be > 0.
    /// @param signature  ABI-packed `r,s,v` ECDSA signature over the EIP-712 batch digest.
    function execute(Call[] calldata calls, uint48 validAfter, uint48 validUntil, bytes calldata signature)
        external
        payable;

    /// @notice Executes a batch directly. Caller must be the owner (`address(this)`).
    function executeBatch(Call[] calldata calls) external payable;

    /// @notice Non-mutating preflight that mirrors {execute}'s validity checks.
    ///
    /// @dev Returns `false` for empty batches, invalid time windows, or failed signature
    ///      verification. Does not validate target-call success or balances.
    function verifyExecuteSignature(
        Call[] calldata calls,
        uint48 validAfter,
        uint48 validUntil,
        bytes calldata signature
    ) external view returns (bool valid);

    /// @notice Returns the current sponsored-execution nonce.
    function getNonce() external view returns (uint256);

    /// @notice Computes the EIP-712 batch digest used by {execute}.
    function computeBatchDigest(uint256 nonce, uint48 validAfter, uint48 validUntil, Call[] calldata calls)
        external
        view
        returns (bytes32);

    /// @notice Returns the EIP-712 domain separator for this account.
    function domainSeparator() external view returns (bytes32);
}
