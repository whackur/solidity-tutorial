# Q-26. Meta-transaction — ERC-2771 gasless increment

> **Difficulty**: Intermediate ⭐⭐⭐

`MetaCounter` trusts a `MyForwarder` (ERC-2771). Instead of calling
`increment()` directly, you **sign** a ForwardRequest off-chain and let the
forwarder relay it. Because the counter trusts the forwarder, it reads
`_msgSender()` as *you* (the signer) — even though the forwarder sent the
actual transaction and paid the gas.

## Goal

Make `MetaCounter.isSolved(you)` return `true`, i.e. `counterOf[you] > 0`,
where `you` is the **recovered signer** of the forward request — not whoever
relays it.

## Contract surface

```solidity
// MyForwarder (OZ ERC2771Forwarder)
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

// MetaCounter
function increment() external;                          // reads _msgSender()
function counterOf(address user) external view returns (uint256);
function isSolved(address user) external view returns (bool);
function solve() external;
```

## Solve sequence (conceptual)

1. Build a `ForwardRequestData` with `from = you`, `to = counter`,
   `data = increment()` selector (`0xd09de08a`), a future `deadline`, and a
   `gas` large enough to run `increment`.
2. Sign the EIP-712 `ForwardRequest` typed data using the forwarder's domain
   (`name = "MyForwarder"`, the forwarder address as `verifyingContract`,
   current `nonces(you)`).
3. Call `forwarder.execute(request)` — anyone can relay it (you, the faucet,
   a sponsor). The forwarder appends `from` to the calldata; `MetaCounter`
   recovers it via `_msgSender()`.
4. Call `MetaCounter.solve()` directly to record the on-chain proof.

> A wallet / viem / ethers script signs the typed data. The exact EIP-712
> types match OpenZeppelin's `ERC2771Forwarder.ForwardRequest`.

## Hints

- `_msgSender()` returns the appended `from` only when the caller is the
  trusted forwarder — a direct `increment()` call would credit your EOA the
  normal way too, but the point is to learn the relayed path.
- The signature is over the forwarder's EIP-712 domain, **not** the counter's.
- `nonces(you)` must match; it increments after each executed request.
- `solve()` should be called directly (not through the forwarder), so
  `msg.sender` is your EOA.

## Concepts exercised

- ERC-2771 trusted forwarder + `_msgSender()` override.
- EIP-712 typed-data signing of a ForwardRequest.
- Separation of *who pays gas* (relayer) from *who is authenticated* (signer).
