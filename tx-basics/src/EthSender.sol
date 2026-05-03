// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @notice External-call surface used by {EthSender.forwardToContract} to
///         demonstrate contract-to-contract value transfer with a typed
///         interface (vs. a raw low-level call).
interface IEthMailbox {
    function receivePayable(bytes32 tag) external payable;
}

/// @title EthSender
/// @notice One contract, many ways to move ETH. Each function exhibits a
///         distinct path so tests can compare semantics, gas envelopes, and
///         failure modes side-by-side.
///
/// @dev Three transfer dimensions are demonstrated:
///       1. EOA → this contract (via {receive}).
///       2. This contract → another address using its own balance:
///          {sendViaTransfer}, {sendViaSend}, {sendViaCall}, {sendViaSendValue}.
///       3. This contract → another contract (interface call vs. raw call):
///          {forwardToContract}, {forwardWithCall}.
///       Plus an internal-call composition path: {sendAfterFee}.
contract EthSender {
    using Address for address payable;

    /*//////////////////////////////////////////////////////////////
                       (1) EOA → this contract
    //////////////////////////////////////////////////////////////*/

    /// @notice Bare ETH transfers (e.g. `to.transfer`, `to.call{value:}("")`)
    ///         land here. No state mutation so the 2300-gas stipend is enough.
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
              (2) this contract → external address — out of own balance
    //////////////////////////////////////////////////////////////*/

    /// @dev `transfer` forwards exactly 2300 gas and reverts on failure.
    ///      Will fail against any recipient whose receive/fallback writes storage.
    function sendViaTransfer(address payable to, uint256 amount) external {
        to.transfer(amount);
    }

    /// @dev `send` is `transfer` with the throw replaced by a `bool` return.
    function sendViaSend(address payable to, uint256 amount) external returns (bool ok) {
        ok = to.send(amount);
    }

    /// @dev Recommended pattern post-Istanbul: forwards all gas, returns a `bool`,
    ///      reverts here only because we choose to.
    function sendViaCall(address payable to, uint256 amount) external returns (bool ok) {
        (ok,) = to.call{value: amount}("");
        require(ok, "call failed");
    }

    /// @dev OZ {Address.sendValue} — forwards all gas and reverts with a
    ///      typed error on failure. Also bubbles up nested revert reasons.
    function sendViaSendValue(address payable to, uint256 amount) external {
        to.sendValue(amount);
    }

    /*//////////////////////////////////////////////////////////////
        (3) internal-call composition (multi-step inside one tx)
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a fee, retains it, and forwards the remainder via an
    ///         internal call — single transaction, no fan-out.
    /// @param feeBps fee in basis points, capped at 100% (10_000).
    function sendAfterFee(address payable to, uint256 amount, uint16 feeBps) external {
        require(feeBps <= 10_000, "fee too high");
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 net = amount - fee;
        _forwardInternal(to, net);
    }

    /// @dev Internal — counts as a JUMP, not a CALL. No new message frame.
    function _forwardInternal(address payable to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "internal forward failed");
    }

    /*//////////////////////////////////////////////////////////////
            (4) this contract → another contract (cross-contract)
    //////////////////////////////////////////////////////////////*/

    /// @dev Typed interface call — hits the named function on the target,
    ///      ABI-encoded by the compiler.
    function forwardToContract(IEthMailbox target, uint256 amount, bytes32 tag) external {
        target.receivePayable{value: amount}(tag);
    }

    /// @dev Raw low-level call — caller controls the calldata directly so
    ///      this can hit `receive` (data == ""), `fallback` (unknown selector),
    ///      or any named function on the target.
    function forwardWithCall(address payable target, uint256 amount, bytes calldata data)
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = target.call{value: amount}(data);
        require(ok, "low-level call failed");
        return ret;
    }

    /*//////////////////////////////////////////////////////////////
                              WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Pull-payment: caller drains the contract balance to themselves.
    function withdraw() external {
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }
}
