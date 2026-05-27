# Q-06. ERC20 Permit — approve + transferFrom in one signed message

> **Difficulty**: Intermediate ⭐⭐⭐

A single `Q06PermitToken` (EIP-2612) + `Q06PermitChallenge` is deployed.
You hold tokens on your EOA, sign an off-chain permit authorising the
challenge contract as `spender`, then submit the permit + a pull in
one transaction (yours or a relayer's).

## Goal

Make `Q06PermitChallenge.isSolved(yourAddress)` return `true`.

Conditions:
- `usedPermit[you] == true` — you've consumed at least one of your permits.
- `token.nonces(you) > 0` — your EIP-2612 nonce advanced (anti-replay proof).

## Contract surface

```solidity
// Q06PermitToken (EIP-2612)
function mint(address to, uint256 amount) external;   // public faucet
function permit(address owner, address spender, uint256 value, uint256 deadline,
                uint8 v, bytes32 r, bytes32 s) external;
function nonces(address owner) external view returns (uint256);
function DOMAIN_SEPARATOR() external view returns (bytes32);

// Q06PermitChallenge
function spendWithPermit(
    address owner,
    uint256 value,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s,
    address recipient
) external;
function isSolved(address user) external view returns (bool);
```

## What you can interact with

- A mintable ERC-20 that supports permit.
- A challenge contract that consumes a signed permit and then spends through `transferFrom`.

## Hints

- The important part is the signed typed data, not the UI wrapper you use to produce it.
- Make sure the permit matches the token, the challenge, and your own address context.
- Once the permit is accepted, the contract performs the spending step in the same transaction.

## Constraints

- The challenge is about signed approval, not about guessing hidden constants.
- Keep the signature bound to your own instance so it cannot be reused elsewhere.

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
