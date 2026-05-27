// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice The challenge's NFT collection. Only the lab (its deployer) can
///         mint; everything else is standard ERC-721 (ownerOf, approve,
///         setApprovalForAll, transferFrom).
contract ChallengeNFT is ERC721 {
    address public immutable lab;
    uint256 public nextId;

    error OnlyLab();

    constructor() ERC721("ChallengeNFT", "cNFT") {
        lab = msg.sender;
    }

    function mintTo(address to) external returns (uint256 id) {
        if (msg.sender != lab) revert OnlyLab();
        id = ++nextId;
        _safeMint(to, id);
    }
}

/// @notice Multi-tenant ERC-721 challenge. A single lab is shared by all
///         students; per-user state is keyed by msg.sender.
///
///         Goal (per caller):
///           1. claim() — mint yourself one NFT.
///           2. approve(lab, tokenId) on the NFT — let the lab move it.
///           3. deposit(tokenId) — the lab pulls your NFT via transferFrom.
///
///         Step 2 is the point: the lab is NOT the owner, so the pull in
///         deposit() only succeeds if you approved the lab first. That is the
///         ERC-721 approval flow, the same shape as ERC-20 approve/transferFrom.
contract NftLab is SolvableBase {
    ChallengeNFT public immutable nft;

    mapping(address => uint256) public claimedToken; // tokenId (0 = not claimed)
    mapping(address => bool) public deposited;

    event Claimed(address indexed user, uint256 tokenId);
    event Deposited(address indexed user, uint256 tokenId);

    error AlreadyClaimed();
    error NotYourClaim();

    constructor() {
        nft = new ChallengeNFT();
    }

    function claim() external returns (uint256 id) {
        if (claimedToken[msg.sender] != 0) revert AlreadyClaimed();
        id = nft.mintTo(msg.sender);
        claimedToken[msg.sender] = id;
        emit Claimed(msg.sender, id);
    }

    /// @notice The lab pulls your token. Requires a prior
    ///         `nft.approve(lab, tokenId)` (or setApprovalForAll) because the
    ///         lab is not the token owner.
    function deposit(uint256 tokenId) external {
        if (claimedToken[msg.sender] != tokenId) revert NotYourClaim();
        nft.transferFrom(msg.sender, address(this), tokenId);
        deposited[msg.sender] = true;
        emit Deposited(msg.sender, tokenId);
    }

    function isSolved(address user) public view override returns (bool) {
        return deposited[user];
    }
}
