# Q-10. Signature replay — weak authorization context

> **Difficulty**: Intermediate ⭐⭐⭐

A `Q10ReplayLab` is deployed. Each user creates a personal `Q10VulnerableSigClaim` seeded with a dedicated mock ERC-20 token (`TKN`) that the lab mints — no ETH funding is required, only gas. The claim contract verifies a signature over too little context: it is missing the fields that normally make an authorization one-time, time-bounded, chain-specific, and contract-specific.

## Goal

Make `Q10ReplayLab.isSolved(yourAddress)` return `true` for your personal claim contract.

## Contract surface

```solidity
// Lab
function createInstance(address signer) external returns (address claim);
function claimOf(address user) external view returns (Q10VulnerableSigClaim);
function tokenOf(address user) external view returns (Q10MockToken);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 5e18; // 5 TKN

// Q10VulnerableSigClaim (your personal instance, signer = the addr you passed)
function claim(address to, uint256 amount, bytes calldata signature) external;
function signer() external view returns (address);
function token() external view returns (Q10MockToken);
```

## The bug under attack

The vulnerable claim path authenticates a payout request with a digest that does not include enough replay-protection context. In particular, it omits the values that would normally bind a signature to a single use, time window, chain, and verifying contract.

If the contract cannot distinguish "first use" from "later use", the signature authorization may remain valid longer than intended.

## What you can interact with

- A claim contract that checks a signature over a narrow set of fields.
- A personal instance seeded with mock ERC-20 tokens (`TKN`).

## Hints

- Ask yourself which replay-protection fields are missing from the signed payload.
- Check whether a successful authorization changes the data that future authorization checks rely on.
- The lesson is about message design, not about a special wallet feature.

## Constraints

- Keep the signed message tied to your own instance.
- Do not assume a one-time signature becomes invalid automatically.

## Concepts exercised

- **Replay attack on signature-authenticated payouts**: the bare minimum
  hash `(to, amount)` lets the same signature be reused.
- **The "four anti-replay fields"**: nonce, deadline, chainId, verifyingContract.
  EIP-712 typed data wraps the latter two into the domain separator;
  the contract still must add nonce + (optional) deadline.
- **Why EIP-712 alone isn't enough**: a typed payload without a nonce
  still replays on the same chain + contract. A SafeSigClaim patch
  would include `nonces[signer]++` or a one-shot used-id mapping.

## A patched version

```solidity
mapping(uint256 => bool) public used;
function claim(address to, uint256 amount, uint256 nonce, uint256 deadline,
               bytes calldata signature) external {
    require(block.timestamp <= deadline, "expired");
    require(!used[nonce], "replay");
    used[nonce] = true;
    bytes32 raw = keccak256(abi.encode(block.chainid, address(this), to, amount, nonce, deadline));
    bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
    require(ECDSA.recover(ethHash, signature) == signer, "bad sig");
    token.transfer(to, amount);
}
```
