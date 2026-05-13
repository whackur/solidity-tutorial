# Q-06. ERC20 Permit — approve + transferFrom in one signed message

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-06-erc20-permit.md`](../../solidity-tutorial-lecture/docs/challenges/q-06-erc20-permit.md)
> **Lecture (Korean)**: [PPT 3-2](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-2-erc20.md), [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md)

A single `PermitToken` (EIP-2612) + `PermitChallenge` is deployed.
You hold tokens on your EOA, sign an off-chain permit authorising the
challenge contract as `spender`, then submit the permit + a pull in
one transaction (yours or a relayer's).

## Goal

Make `PermitChallenge.isSolved(yourAddress)` return `true`.

Conditions:
- `usedPermit[you] == true` — you've consumed at least one of your permits.
- `token.nonces(you) > 0` — your EIP-2612 nonce advanced (anti-replay proof).

## Contract surface

```solidity
// PermitToken (EIP-2612)
function mint(address to, uint256 amount) external;   // public faucet
function permit(address owner, address spender, uint256 value, uint256 deadline,
                uint8 v, bytes32 r, bytes32 s) external;
function nonces(address owner) external view returns (uint256);
function DOMAIN_SEPARATOR() external view returns (bytes32);

// PermitChallenge
function spendWithPermit(
    address owner,
    uint256 value,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s,
    address recipient
) external;
function isSolved(address user) external view returns (bool);
```

## UI call sequence

1. `token.mint(you, 100e18)` — self-faucet.
2. Off-chain: sign EIP-712 typed data for the Permit struct. In a web UI
   this is a single `eth_signTypedData_v4` call. The signed struct is:
   ```
   domain: {
     name: "PermitToken",
     version: "1",
     chainId,
     verifyingContract: tokenAddress
   }
   types: { Permit: [owner, spender, value, nonce, deadline] }
   message: {
     owner: you,
     spender: challengeAddress,
     value: 100e18,
     nonce: token.nonces(you),
     deadline: now + 1h
   }
   ```
3. Split the resulting 65-byte signature into `(v, r, s)`.
4. Submit `challenge.spendWithPermit(you, 100e18, deadline, v, r, s, recipient)`.
   - The challenge calls `token.permit(...)` then `transferFrom(you → recipient)` atomically.
5. Read `challenge.isSolved(you)` → `true`.

## Concepts exercised

- **EIP-2612 permit**: replaces a separate `approve` tx with an off-chain
  signature that the `permit` function consumes on-chain.
- **EIP-712 typed data**: structured digest = `\x19\x01 || domainSeparator || structHash`.
  The wallet's signing UI shows the field names instead of an opaque hash.
- **Nonce-based replay protection**: each successful permit increments
  `nonces[owner]`, invalidating the previous signature.
- **Relayer pattern**: the permit holder doesn't have to be the tx sender,
  enabling gasless / meta-transaction flows (only the recipient is fixed
  inside the signed payload; the relayer pays gas).
