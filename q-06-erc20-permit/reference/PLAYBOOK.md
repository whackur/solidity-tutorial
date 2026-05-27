# Q-06 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`T` = deployed `Q06PermitToken`. `C` = deployed `Q06PermitChallenge` (with `T`).
`USER` = user's EOA. `R` = recipient chosen by user.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `T` | `mint(address,uint256)` | `(USER, 100e18)` | self-faucet |
| 2 | off-chain | wallet | `eth_signTypedData_v4` | EIP-712 Permit struct (see below) | wallet returns 65-byte `(v,r,s)` sig |
| 3 | `USER` (or relayer) | `C` | `spendWithPermit(address,uint256,uint256,uint8,bytes32,bytes32,address)` | `(USER, 100e18, deadline, v, r, s, R)` | sets `usedPermit[USER]`; advances `T.nonces(USER)` |
| 4 | view | `T` | `balanceOf(R)` | — | `100e18` |
| 5 | view | `C` | `isSolved(USER)` | — | `true` |

### EIP-712 Permit payload signed in step 2

```jsonc
{
  "types": {
    "Permit": [
      { "name": "owner",    "type": "address" },
      { "name": "spender",  "type": "address" },
      { "name": "value",    "type": "uint256" },
      { "name": "nonce",    "type": "uint256" },
      { "name": "deadline", "type": "uint256" }
    ]
  },
  "domain": {
    "name": "Q06PermitToken",
    "version": "1",
    "chainId": <currentChain>,
    "verifyingContract": "<T address>"
  },
  "primaryType": "Permit",
  "message": {
    "owner":    "<USER>",
    "spender":  "<C address>",
    "value":    "100000000000000000000",
    "nonce":    <T.nonces(USER) before this signature>,
    "deadline": <now + 3600>
  }
}
```

## Notes

- Step 3 can be sent from any address — only the *signer* (USER) gets
  solve credit. Useful for demonstrating gasless / meta-tx flows.
- Re-submitting the same `(owner, value, deadline, v, r, s)` reverts:
  `permit` checks the current nonce, which advanced after the first call.
- `nonces(USER)` > 0 plus `usedPermit[USER]` is what `isSolved` checks.
