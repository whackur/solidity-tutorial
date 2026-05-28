# Q-24. NFT ownership — approval flow

> **Difficulty**: Entry ⭐

A shared `Q24NftLab` mints you an ERC-721 token, then asks you to reason about how a non-owner contract can move that token. This is the ERC-721 approval flow — the same shape as ERC-20 `approve` / `transferFrom`.

## Goal

Make `Q24NftLab.isSolved(you)` return `true`, which requires `deposited[you] == true`.

## Contract surface

```solidity
// Q24NftLab
function claim() external returns (uint256 id);        // mint one NFT to you
function deposit(uint256 tokenId) external;
function claimedToken(address user) external view returns (uint256);
function deposited(address user) external view returns (bool);
function nft() external view returns (Q24ChallengeNFT);
function isSolved(address user) external view returns (bool);
function solve() external;
function solvedBy(address user) external view returns (bool);

// Q24ChallengeNFT (standard ERC-721)
function approve(address to, uint256 tokenId) external;
function setApprovalForAll(address operator, bool approved) external;
function ownerOf(uint256 tokenId) external view returns (address);
```

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

- A contract that is not the current owner needs explicit approval before it can move an ERC-721 token.
- Token-specific approval and operator-wide approval have different blast radii.
- `ownerOf(tokenId)` lets you confirm where the token currently lives.

## Concepts exercised

- ERC-721 `_safeMint`, `ownerOf`, unique `tokenId` per token.
- Approval flow: `approve` / `setApprovalForAll` then a third party calls
  `transferFrom`.
- Why a contract that is not the owner needs explicit approval to move tokens.
