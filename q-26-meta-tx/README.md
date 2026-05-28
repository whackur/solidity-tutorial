# Q-26. Meta-transaction — ERC-2771 recovered sender

> **Difficulty**: Intermediate ⭐⭐⭐

`Q26MetaCounter` trusts a `Q26MyForwarder` (ERC-2771). The exercise is about separating the relayer that submits a transaction from the signer that the target contract treats as the authenticated sender.

## Goal

Make `Q26MetaCounter.isSolved(you)` return `true`, i.e. `counterOf[you] > 0`,
where `you` is the **recovered signer** of the forward request — not whoever
relays it.

## Contract surface

```solidity
// Q26MyForwarder (OZ ERC2771Forwarder)
struct ForwardRequestData {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint48  deadline;
    bytes   data;
    bytes   signature;
}
function execute(ForwardRequestData calldata request) external payable;
function nonces(address owner) external view returns (uint256);

// Q26MetaCounter
function increment() external;                          // reads _msgSender()
function counterOf(address user) external view returns (uint256);
function isSolved(address user) external view returns (bool);
function solve() external;
```

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

## Hints

- `_msgSender()` has special behavior only when the caller is the trusted forwarder.
- The relevant EIP-712 domain belongs to the forwarder.
- `nonces(you)` must match; it increments after each executed request.
- Be clear about which contract reads `_msgSender()` and which function still
  uses ordinary `msg.sender`.

## Concepts exercised

- ERC-2771 trusted forwarder + `_msgSender()` override.
- EIP-712 typed-data signing of a ForwardRequest.
- Separation of *who pays gas* (relayer) from *who is authenticated* (signer).
