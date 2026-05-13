# Q-07 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`C` = deployed `EthSignChallenge`. `USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `C` | `startChallenge()` | — | writes `challengeOf[USER]` = `keccak256(USER, block.timestamp, block.prevrandao)` |
| 2 | view | `C` | `challengeOf(USER)` | — | grab the 32-byte hash |
| 3 | off-chain | wallet | `personal_sign(challengeBytes32)` | — | wallet returns 65-byte `(r,s,v)` over `EIP-191("\x19Ethereum Signed Message:\n32" + hash)` |
| 4 | `USER` | `C` | `submitEthSign(bytes)` | `signature` | sets `solvedEthSign[USER]` |
| 5 | off-chain | wallet | `personal_sign("hello, personal_sign world!")` | — | wallet signs `"\x19Ethereum Signed Message:\n27" + message` |
| 6 | `USER` | `C` | `submitPersonalSign(bytes,bytes)` | `(messageBytes, signature)` | sets `solvedPersonalSign[USER]` |
| 7 | view | `C` | `isSolved(USER)` | — | `true` |

## Notes

- viem reference:
  ```ts
  // step 3
  const sig = await walletClient.signMessage({ message: { raw: challenge } });
  // step 5
  const sig2 = await walletClient.signMessage({ message: "hello, personal_sign world!" });
  ```
- The contract reverts with `"signature must be from msg.sender"` if
  the recovered signer != caller — i.e. the signature must be made by
  the wallet that's now sending the verification tx.
- Calling `startChallenge()` again *re-rolls* the challenge hash. If the
  user signs first and then re-rolls, the prior signature stops working.
- Test harness runs Alice + Bob in parallel under `vm.prank` and verifies
  per-user `challengeOf` + solve flags.
