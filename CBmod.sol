// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {BasePlugin} from "@alchemy/modular-account/src/plugins/BasePlugin.sol";
import {
    ManifestFunction,
    ManifestAssociatedFunctionType,
    ManifestAssociatedFunction,
    PluginManifest,
    PluginMetadata
} from "@alchemy/modular-account/src/interfaces/IPlugin.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title NFT Burn Tracking Plugin
/// @author Elisha Day
/// @notice This plugin lets you track and auto-burn unclaimed NFTs after a specified delay.
contract CBNFTBurnTrackingPlugin is BasePlugin {
    using EnumerableSet for EnumerableSet.UintSet;

    string public constant NAME = "Cosmic Bots NFT Burn Tracking Plugin";
    string public constant VERSION = "1.0.0";
    string public constant AUTHOR = "Elisha Day";

    uint256 private constant AUTO_BURN_DELAY = 8 hours;

    mapping(address => EnumerableSet.UintSet) private _burntNFTSet;
    mapping(address => mapping(uint256 => uint256)) private _lastClaimTimestamp;

    event NFTBurnt(address indexed account, address indexed nftContract, uint256 indexed tokenId);

    function executeAutoBurn(address nftContract, uint256 tokenId) external {
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(owner == address(msg.sender), "The modular account must own the NFT");
        require(block.timestamp >= _lastClaimTimestamp[nftContract][tokenId] + AUTO_BURN_DELAY, "Auto-burn delay has not passed");
        
        IERC721(nftContract).safeTransferFrom(address(msg.sender), address(0), tokenId);
        _burntNFTSet[address(msg.sender)].add(tokenId);
        emit NFTBurnt(address(msg.sender), nftContract, tokenId);
    }

    function getBurntNFTCount(address account) external view returns (uint256) {
        EnumerableSet.UintSet storage burntNFTSet = _burntNFTSet[account];
        return burntNFTSet.length();
    }

    function addToBurntNFTSet(address nftContract, uint256 tokenId) external {
        require(address(msg.sender) == msg.sender, "Only the modular account can add to burnt NFT set");
        IERC721(nftContract).safeTransferFrom(address(msg.sender), address(0), tokenId);
        _burntNFTSet[address(msg.sender)].add(tokenId);
        emit NFTBurnt(address(msg.sender), nftContract, tokenId);
    }

    function onInstall(bytes calldata) external pure override {}

    function onUninstall(bytes calldata) external pure override {}

    function pluginManifest() external pure override returns (PluginManifest memory manifest) {
        manifest.executionFunctions = new bytes4[](3);
        manifest.executionFunctions[0] = this.executeAutoBurn.selector;
        manifest.executionFunctions[1] = this.addToBurntNFTSet.selector;
        manifest.executionFunctions[2] = this.updateLastClaimTimestamp.selector;

        manifest.runtimeValidationHooks = new ManifestAssociatedFunction[](3);
        manifest.runtimeValidationHooks[0] = ManifestAssociatedFunction({
            executionSelector: this.executeAutoBurn.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.RUNTIME_HOOK_ALWAYS_ALLOW,
                functionId: 0,
                dependencyIndex: 0
            })
        });
        manifest.runtimeValidationHooks[1] = ManifestAssociatedFunction({
            executionSelector: this.addToBurntNFTSet.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.RUNTIME_HOOK_ALWAYS_ALLOW,
                functionId: 0,
                dependencyIndex: 0
            })
        });
        manifest.runtimeValidationHooks[2] = ManifestAssociatedFunction({
            executionSelector: this.updateLastClaimTimestamp.selector,
            associatedFunction: ManifestFunction({
                functionType: ManifestAssociatedFunctionType.RUNTIME_HOOK_ALWAYS_ALLOW,
                functionId: 0,
                dependencyIndex: 0
            })
        });
    }

    function pluginMetadata() external pure override returns (PluginMetadata memory metadata) {
        metadata.name = NAME;
        metadata.version = VERSION;
        metadata.author = AUTHOR;
    }

    function updateLastClaimTimestamp(address nftContract, uint256 tokenId) external {
        require(address(msg.sender) == msg.sender, "Only the modular account can update last claim timestamp");
        _lastClaimTimestamp[nftContract][tokenId] = block.timestamp;
    }
}
