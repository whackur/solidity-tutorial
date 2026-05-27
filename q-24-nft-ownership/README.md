# Q-24. NFT ownership — claim, approve, deposit

> **Difficulty**: Entry ⭐

A shared `NftLab` mints you an ERC-721 token, then asks you to hand it back.
The catch: the lab is not the token owner, so it can only take your NFT if
you **approve** it first. This is the ERC-721 approval flow — the same shape
as ERC-20 `approve` / `transferFrom`.

## Goal

Make `NftLab.isSolved(you)` return `true`, which requires `deposited[you] == true`.

## Contract surface

```solidity
// NftLab
function claim() external returns (uint256 id);        // mint one NFT to you
function deposit(uint256 tokenId) external;            // lab pulls it (needs approval)
function claimedToken(address user) external view returns (uint256);
function deposited(address user) external view returns (bool);
function nft() external view returns (ChallengeNFT);
function isSolved(address user) external view returns (bool);
function solve() external;
function solvedBy(address user) external view returns (bool);

// ChallengeNFT (standard ERC-721)
function approve(address to, uint256 tokenId) external;
function setApprovalForAll(address operator, bool approved) external;
function ownerOf(uint256 tokenId) external view returns (address);
```

## Solve sequence

```bash
LAB=<lab address>
NFT=$(cast call $LAB "nft()(address)" --rpc-url http://localhost:8545)

# 1. claim — mint yourself a token
cast send $LAB "claim()" --rpc-url http://localhost:8545 --private-key <yours>
ID=$(cast call $LAB "claimedToken(address)(uint256)" <you> --rpc-url http://localhost:8545)

# 2. approve the lab to move your token
cast send $NFT "approve(address,uint256)" $LAB $ID --rpc-url http://localhost:8545 --private-key <yours>

# 3. deposit — the lab pulls it via transferFrom (only works because of step 2)
cast send $LAB "deposit(uint256)" $ID --rpc-url http://localhost:8545 --private-key <yours>

# 4. solve
cast send $LAB "solve()" --rpc-url http://localhost:8545 --private-key <yours>
```

## Hints

- Skipping the `approve` step makes `deposit` revert — the lab is not the
  owner, so `transferFrom` is unauthorized without approval.
- `setApprovalForAll(lab, true)` also works and authorizes the lab for every
  token you own, not just one.
- `ownerOf(tokenId)` lets you confirm the token moved to the lab.

## Concepts exercised

- ERC-721 `_safeMint`, `ownerOf`, unique `tokenId` per token.
- Approval flow: `approve` / `setApprovalForAll` then a third party calls
  `transferFrom`.
- Why a contract that is not the owner needs explicit approval to move tokens.
