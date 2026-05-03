// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract MyERC721Test is Test, IERC721Receiver {
    MyERC721 internal nft;
    address internal owner = address(this);

    function setUp() public {
        nft = new MyERC721("MyERC721", "ME7");
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function test_Metadata() public view {
        assertEq(nft.name(), "MyERC721");
        assertEq(nft.symbol(), "ME7");
    }

    function test_SafeMintAssignsToken() public {
        nft.safeMint(owner, "ipfs://example");

        assertEq(nft.balanceOf(owner), 1);
        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.tokenURI(0), "ipfs://example");
    }

    function test_SequentialMintIncrementsTokenId() public {
        nft.safeMint(owner, "");
        nft.safeMint(owner, "");

        assertEq(nft.balanceOf(owner), 2);
        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.ownerOf(1), owner);
    }
}
