// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice The challenge's NFT collection. Only the lab (its deployer) can
///         mint; everything else is standard ERC-721 (ownerOf, approve,
///         setApprovalForAll, transferFrom).
contract Q24ChallengeNFT is ERC721 {
    address public immutable lab;
    uint256 public nextId;

    error OnlyLab();

    constructor() ERC721("Q24ChallengeNFT", "cNFT") {
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
///         The lab is not the token owner, so this exercise focuses on
///         ERC-721 approval semantics and third-party token movement.
contract Q24NftLab is SolvableBase {
    Q24ChallengeNFT public immutable nft;

    mapping(address => uint256) public claimedToken; // tokenId (0 = not claimed)
    mapping(address => bool) public deposited;

    event Claimed(address indexed user, uint256 tokenId);
    event Deposited(address indexed user, uint256 tokenId);

    error AlreadyClaimed();
    error NotYourClaim();

    constructor() {
        nft = new Q24ChallengeNFT();
    }

    function claim() external returns (uint256 id) {
        if (claimedToken[msg.sender] != 0) revert AlreadyClaimed();
        id = nft.mintTo(msg.sender);
        claimedToken[msg.sender] = id;
        emit Claimed(msg.sender, id);
    }

    /// @notice The lab attempts to move the user's claimed token through the
    ///         standard ERC-721 transfer path.
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
