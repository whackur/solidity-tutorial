// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ISmartAccount} from "./interfaces/ISmartAccount.sol";

/// @title SmartAccount
///
/// @notice Minimal EIP-7702 smart account: ECDSA-verified sponsored batch execution,
///         direct owner batch execution, and ERC-1271 message signing.
///
/// @dev    Single owner = `address(this)`. Under EIP-7702 delegation `address(this)` is
///         the EOA itself, so the EOA private key is the only signing authority.
///
/// @dev    Storage uses ERC-7201 namespaced slots
///         (https://eips.ethereum.org/EIPS/eip-7201). Each storage region is grouped
///         into a struct annotated with `@custom:storage-location erc7201:<namespace>`,
///         and its base slot is derived as
///         `keccak256(abi.encode(uint256(keccak256("erc7201:<namespace>")) - 1)) & ~bytes32(uint256(0xff))`.
///         This guarantees that future implementations the EOA may re-delegate to via
///         EIP-7702 cannot collide with this layout, and that audit / static-analysis
///         tooling (Slither, `forge inspect`, OZ storage layout checker) can verify the
///         layout invariants automatically.
contract SmartAccount is ISmartAccount, IERC1271, IERC165, ReentrancyGuardTransient {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev EIP-712 typehash for a sponsored execution batch.
    bytes32 private constant _BATCH_TYPEHASH =
        keccak256("ExecuteBatch(uint256 nonce,uint48 validAfter,uint48 validUntil,bytes32 callsHash)");

    /// @dev EIP-712 typehash for the ERC-1271 replay-safe message wrapper.
    bytes32 private constant _MESSAGE_TYPEHASH = keccak256("SmartAccountMessage(bytes32 hash)");

    /// @dev EIP-712 domain typehash.
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev Hash of the domain `name` field.
    bytes32 private constant _HASHED_NAME = keccak256("BlackCombatSmartAccount");

    /// @dev Hash of the domain `version` field.
    ///      Bump on any change that alters digest semantics or when invalidating all
    ///      previously issued sponsored / ERC-1271 owner signatures is desired.
    bytes32 private constant _HASHED_VERSION = keccak256("1");

    /// @dev ERC-1271 magic return value for a valid signature.
    bytes4 private constant _ERC1271_MAGIC = 0x1626ba7e;

    /// @dev Sentinel return value indicating an invalid ERC-1271 signature.
    bytes4 private constant _ERC1271_INVALID = 0xffffffff;

    /*//////////////////////////////////////////////////////////////
                          ERC-7201 STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Account-wide persistent state. Wrapped in a struct (rather than declared
    ///         as a bare `uint256`) so future fields can be appended without disturbing
    ///         the namespace base slot, and so tooling can track the layout via the
    ///         `@custom:storage-location` annotation.
    ///
    /// @custom:storage-location erc7201:black-combat.SmartAccount.main
    struct MainStorage {
        uint256 nonce;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("erc7201:black-combat.SmartAccount.main")) - 1))
    ///        & ~bytes32(uint256(0xff))
    bytes32 private constant _MAIN_STORAGE_SLOT = 0x33be3f0b8e02d4b587ab3575978f8f9bebd71dcafc8904fbef10b1eea6787500;

    /// @dev Transient slot for the OZ {ReentrancyGuardTransient} lock.
    ///      EIP-1153 transient storage is keyed independently of regular storage but
    ///      the namespace convention is reused for consistency and auditability.
    ///      Derivation:
    ///      keccak256(abi.encode(uint256(keccak256("erc7201:black-combat.SmartAccount.transient")) - 1))
    ///        & ~bytes32(uint256(0xff))
    bytes32 private constant _REENTRANCY_TRANSIENT_SLOT =
        0xc78c922e2c0d17bfff4c4c487ea73e034d64f36bf0bdea0071f382b1d785b800;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Restricts a function to the account owner — i.e. self-calls or the EOA itself
    ///      under EIP-7702 delegation, both of which appear as `msg.sender == address(this)`.
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != address(this)) revert Unauthorized();
    }

    /*//////////////////////////////////////////////////////////////
                                 RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Allow the account to receive native asset.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                               EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISmartAccount
    function execute(Call[] calldata calls, uint48 validAfter, uint48 validUntil, bytes calldata signature)
        external
        payable
        virtual
        nonReentrant
    {
        if (calls.length == 0) revert EmptyBatch();
        _checkValidity(validAfter, validUntil);

        MainStorage storage $ = _mainStorage();
        uint256 currentNonce = $.nonce;
        bytes32 callsHash = keccak256(abi.encode(calls));
        bytes32 digest = _computeBatchDigest(currentNonce, validAfter, validUntil, callsHash);

        if (!_verifyOwnerSignature(digest, signature)) revert InvalidSignature();

        unchecked {
            $.nonce = currentNonce + 1;
        }
        _executeBatch(calls);

        emit BatchExecuted(currentNonce, callsHash, calls.length);
    }

    /// @inheritdoc ISmartAccount
    function executeBatch(Call[] calldata calls) external payable virtual onlyOwner nonReentrant {
        if (calls.length == 0) revert EmptyBatch();
        _executeBatch(calls);
        emit BatchDirectExecuted(msg.sender, calls.length);
    }

    /*//////////////////////////////////////////////////////////////
                          SIGNATURE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISmartAccount
    function verifyExecuteSignature(
        Call[] calldata calls,
        uint48 validAfter,
        uint48 validUntil,
        bytes calldata signature
    ) external view virtual returns (bool) {
        if (calls.length == 0) return false;
        if (validUntil == 0) return false;
        if (validAfter > 0 && block.timestamp < validAfter) return false;
        if (block.timestamp > validUntil) return false;

        bytes32 digest = _computeBatchDigest(_mainStorage().nonce, validAfter, validUntil, keccak256(abi.encode(calls)));
        return _verifyOwnerSignature(digest, signature);
    }

    /// @notice ERC-1271 signature validation against an account-bound replay-safe hash.
    ///
    /// @dev Wraps the input hash in an EIP-712 envelope keyed to this account's chain id
    ///      and address before recovering, so a signature for one account cannot be
    ///      replayed on another EIP-7702 delegation of the same EOA on another chain.
    function isValidSignature(bytes32 hash, bytes calldata signature) external view virtual override returns (bytes4) {
        return _verifyOwnerSignature(_replaySafeHash(hash), signature) ? _ERC1271_MAGIC : _ERC1271_INVALID;
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISmartAccount
    function getNonce() external view returns (uint256) {
        return _mainStorage().nonce;
    }

    /// @inheritdoc ISmartAccount
    function computeBatchDigest(uint256 nonce, uint48 validAfter, uint48 validUntil, Call[] calldata calls)
        external
        view
        returns (bytes32)
    {
        return _computeBatchDigest(nonce, validAfter, validUntil, keccak256(abi.encode(calls)));
    }

    /// @notice ERC-165 interface introspection.
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(ISmartAccount).interfaceId || interfaceId == type(IERC1271).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                              PUBLIC VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISmartAccount
    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(abi.encode(_EIP712_DOMAIN_TYPEHASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL: REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/

    function _reentrancyGuardStorageSlot() internal pure override returns (bytes32) {
        return _REENTRANCY_TRANSIENT_SLOT;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL: EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Sequentially calls each entry in the batch. Reverts on the first failed call,
    ///      bubbling up the underlying revert data via OpenZeppelin's {Address}.
    function _executeBatch(Call[] calldata calls) internal {
        uint256 len = calls.length;
        for (uint256 i; i < len;) {
            Address.functionCallWithValue(calls[i].target, calls[i].data, calls[i].value);
            unchecked {
                ++i;
            }
        }
    }

    function _checkValidity(uint48 validAfter, uint48 validUntil) internal view {
        if (validUntil == 0) revert ValidUntilZero();
        if (validAfter > 0 && block.timestamp < validAfter) {
            revert ValidAfterNotReached(validAfter, block.timestamp);
        }
        if (block.timestamp > validUntil) revert ValidUntilExpired(validUntil, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL: SIGNATURE / DIGEST
    //////////////////////////////////////////////////////////////*/

    function _computeBatchDigest(uint256 nonce, uint48 validAfter, uint48 validUntil, bytes32 callsHash)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash =
            keccak256(abi.encode(_BATCH_TYPEHASH, nonce, uint256(validAfter), uint256(validUntil), callsHash));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    function _replaySafeHash(bytes32 hash) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(_MESSAGE_TYPEHASH, hash));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));
    }

    /// @dev Recovers `signature` over `hash` and checks the recovered address equals
    ///      `address(this)` — the EIP-7702 EOA owner. Rejects malleable / malformed sigs.
    function _verifyOwnerSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        return err == ECDSA.RecoverError.NoError && recovered == address(this);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE: STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the namespaced storage struct.
    function _mainStorage() private pure returns (MainStorage storage $) {
        bytes32 slot = _MAIN_STORAGE_SLOT;
        assembly ("memory-safe") {
            $.slot := slot
        }
    }
}
