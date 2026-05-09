# erc1155-multi-token

> Companion sample for the ERC-1155 portion of lecture chapter *3-3 (NFT issuance and operations)*.

## Goals

- See why ERC-1155's `(holder, id) → amount` mapping is *two-dimensional* — one contract issues many token kinds.
- Watch how `mint` / `mintBatch` / `safeBatchTransferFrom` / `balanceOfBatch` produce the gas savings that make 1155 attractive.
- Verify the spec rule that `{id}` substitution in `uri(id)` happens *off-chain*, not on-chain.

## Key points

- ERC-721: every token has its own owner — `mapping(uint256 => address)`.
- ERC-1155: `mapping(uint256 => mapping(address => uint256))` for `(holder, id) → amount`.
- One contract handles fungibles (GOLD/SILVER) and non-fungibles (SWORD) at the same time, which is why game studios reach for ERC-1155.
- `uri(id)` returns the template literally; the lowercase 64-char hex substitution happens client-side, so it costs zero on-chain gas.

## Files

| File | Topic |
|---|---|
| `src/GameItems.sol` | GOLD / SILVER (FT) + SWORD (NFT) mix, `mintBatch` showcase |
| `test/GameItems.t.sol` | mint / mintBatch / balanceOfBatch / safeBatchTransferFrom |
