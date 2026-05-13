# Q-08 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`C` = deployed `VoucherChallenge`. `T` = `C.token()` (`VoucherToken`).
`USER` = user's EOA. `ID` = a globally-unique `uint256` voucher id.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | view | `C` | `token()`, `domainSeparator()` | — | snapshot |
| 2 | view | `C` | `computeDigest(address,address,uint256,uint256)` | `(USER, USER, ID, 50e18)` | optional: lets the UI cross-check its off-chain digest |
| 3 | off-chain | wallet | `eth_signTypedData_v4` | EIP-712 Voucher (see below) | wallet returns 65-byte `(r,s,v)` |
| 4 | `USER` | `C` | `redeemVoucher(address,address,uint256,uint256,bytes)` | `(USER, USER, ID, 50e18, sig)` | sets `solved[USER]`, `usedVouchers[ID]`; mints `50e18` `VCH` to USER |
| 5 | view | `T` | `balanceOf(USER)` | — | `50e18` |
| 6 | view | `C` | `isSolved(USER)` | — | `true` |

### EIP-712 Voucher payload signed in step 3

```jsonc
{
  "types": {
    "Voucher": [
      { "name": "token",     "type": "address" },
      { "name": "signer",    "type": "address" },
      { "name": "redeemer",  "type": "address" },
      { "name": "voucherId", "type": "uint256" },
      { "name": "amount",    "type": "uint256" }
    ]
  },
  "domain": {
    "name": "MyEIP712App",
    "version": "1",
    "chainId": <currentChain>,
    "verifyingContract": "<C address>"
  },
  "primaryType": "Voucher",
  "message": {
    "token":     "<T address>",
    "signer":    "<USER>",
    "redeemer":  "<USER>",
    "voucherId": <ID>,
    "amount":    "50000000000000000000"
  }
}
```

## Notes

- The challenge enforces `signer == redeemer == msg.sender`, so users
  must sign and submit from the same wallet. This intentionally rules
  out the meta-tx / relayer flow (covered separately in q-06).
- Two users picking the *same* `voucherId` causes the second redeem
  to revert with `"Voucher already redeemed"`. UIs should derive the
  id from the user (e.g. `uint256(keccak256(abi.encode(user, nonce)))`)
  to avoid collisions.
- The domain `name == "MyEIP712App"` must match the constructor literal
  byte-for-byte, or the hash differs and `recover` returns the wrong signer.
