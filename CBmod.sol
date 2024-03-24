// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@ethereum-oauth/module-session-key/contracts/ModularSessionKeyPlugin.sol";

contract NFTBurnTrackingPlugin is ModularSessionKeyPlugin {
    using EnumerableSet for EnumerableSet.UintSet;

    string public constant NAME = "NFT Burn Tracking Plugin";
    string public constant VERSION = "1.0.0";
    string public constant AUTHOR = "Your Name";

    mapping(address account => EnumerableSet.UintSet) private _burntNFTSet;

    event NFTBurnt(address indexed account, address indexed nftContract, uint256 indexed tokenId);

    function burnNFT(address nftContract, uint256 tokenId) external {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");

        IERC721(nftContract).transferFrom(msg.sender, address(0), tokenId);
        _burntNFTSet[msg.sender].add(tokenId);

        emit NFTBurnt(msg.sender, nftContract, tokenId);
    }

    function getBurntNFTs(address account) external view returns (uint256[] memory) {
        EnumerableSet.UintSet storage burntNFTSet = _burntNFTSet[account];
        uint256 length = burntNFTSet.length();
        uint256[] memory burntNFTs = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            burntNFTs[i] = burntNFTSet.at(i);
        }
        return burntNFTs;
    }

    function executeAutoBurn(address nftContract, uint256 tokenId) external {
        require(installedPlugins[msg.sender], "Only installed plugins can initiate auto-burn");

        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(owner == address(this), "The modular account must own the NFT");

        IERC721(nftContract).transferFrom(address(this), address(0), tokenId);
        _burntNFTSet[address(this)].add(tokenId);

        emit NFTBurnt(address(this), nftContract, tokenId);
    }

    function pluginManifest() external pure override returns (PluginManifest memory) {
        PluginManifest memory manifest = super.pluginManifest();

      manifest.executionFunctions = new bytes4[](2);
        manifest.executionFunctions[0] = this.burnNFT.selector;
        manifest.executionFunctions[1] = this.executeAutoBurn.selector;

        // Add any necessary user operation validation and runtime validation functions

        return manifest;
    }

    function pluginMetadata() external pure override returns (PluginMetadata memory) {
        PluginMetadata memory metadata = super.pluginMetadata();
        metadata.name = NAME;
        metadata.version = VERSION;
        metadata.author = AUTHOR;

        return metadata;
    }
}