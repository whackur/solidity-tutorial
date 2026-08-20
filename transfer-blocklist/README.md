# transfer-blocklist — default allow, explicit operational blocks

This package demonstrates a small default-allow transfer policy. Normal ERC-20 transfers succeed unless the owner explicitly blocks the sender or recipient in `AddressBlocklist`.

`BlocklistRestrictedToken` checks the registry inside `_update`, so wallets and applications do not contain policy rules. Blocking an address stops its next outgoing or incoming transfer; unblocking restores normal transfer behavior.

The public `mint` function exists only for the classroom faucet. Minting is issuance, not a holder-to-holder transfer, but every later transfer of those tokens still passes through the blocklist.

This is not complete STO compliance. Production systems commonly combine eligibility or identity checks with sanctions screening, freezes, limits, recovery, forced transfers, audit evidence, and operating procedures.

## Run

```bash
cd transfer-blocklist
forge build
forge test -vv
```
