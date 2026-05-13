# Q-10. Signature replay — drain your claim with one signature

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-10-signature-replay.md`](../../solidity-tutorial-lecture/docs/challenges/q-10-signature-replay.md)
> **Lecture (Korean)**: [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md), [PPT 4-1](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A pre-funded `ReplayLab` is deployed. Each user calls `createInstance(you)`
once to get a personal `VulnerableSigClaim` seeded with `5 ETH`. The
claim contract verifies a signature over *only* `(to, amount)` — no nonce,
no deadline, no chainId, no verifyingContract. You sign that pair once
and replay the same signature five times to drain the contract.

## Goal

Make `ReplayLab.isSolved(yourAddress)` return `true`: drain *your* claim
contract to `0` ETH.

## Contract surface

```solidity
// Lab
function createInstance(address signer) external returns (address claim);
function claimOf(address user) external view returns (VulnerableSigClaim);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 5 ether;

// VulnerableSigClaim (your personal instance, signer = the addr you passed)
function claim(address payable to, uint256 amount, bytes calldata signature) external;
function signer() external view returns (address);
```

## The bug under attack

```solidity
function claim(address payable to, uint256 amount, bytes calldata signature) external {
    bytes32 raw = keccak256(abi.encode(to, amount));     // ← only (to, amount)
    bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
    address recovered = ECDSA.recover(ethHash, signature);
    require(recovered == signer, "bad sig");
    (bool ok,) = to.call{value: amount}("");
    require(ok, "send failed");
}
```

No nonce, no deadline, no chainId, no verifyingContract in the hash.
The same `(to, amount)` always produces the same digest, so the same
signature is accepted forever.

## UI call sequence

1. `lab.createInstance(you)` — deploys your claim with `signer == you`,
   seeds it with `5 ETH`.
2. Off-chain: sign `(payable(you), 1 ether)` once. In viem:
   ```ts
   const raw = keccak256(encodeAbiParameters(
     [{ type: 'address' }, { type: 'uint256' }],
     [you, parseEther('1')]
   ));
   const sig = await walletClient.signMessage({ message: { raw } });
   ```
3. Submit `claim.claim(you, 1 ether, sig)` *five* times from your wallet.
   Each call drains another `1 ETH`. After five replays, `address(claim).balance == 0`.
4. `lab.isSolved(you)` → `true`.

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
function claim(address payable to, uint256 amount, uint256 nonce, uint256 deadline,
               bytes calldata signature) external {
    require(block.timestamp <= deadline, "expired");
    require(!used[nonce], "replay");
    used[nonce] = true;
    bytes32 raw = keccak256(abi.encode(block.chainid, address(this), to, amount, nonce, deadline));
    bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
    require(ECDSA.recover(ethHash, signature) == signer, "bad sig");
    (bool ok,) = to.call{value: amount}("");
    require(ok, "send failed");
}
```
