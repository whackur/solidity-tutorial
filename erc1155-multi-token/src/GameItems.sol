// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title GameItems — multiple token kinds in a single contract (FT/NFT mix)
/// @notice
///   - id 0 (GOLD), id 1 (SILVER) : fungible resources (issued by quantity)
///   - id 2 (SWORD) : non-fungible weapon (quantity 1)
///   - `uri(id)` pattern: clients substitute `{id}` with a 64-char lowercase hex string at read time.
contract GameItems is ERC1155, Ownable {
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant SWORD = 2;

    constructor(address initialOwner)
        ERC1155("ipfs://bafy.../{id}.json")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }
}
