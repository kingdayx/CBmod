// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IERC721Burnable} from "./IERC721.sol";
import {BasePlugin} from "../lib/modular-account/src/plugins/BasePlugin.sol";
import {
    ManifestFunction,
    ManifestAssociatedFunctionType,
    ManifestAssociatedFunction,
    PluginManifest,
    PluginMetadata
} from "../lib/modular-account/src/interfaces/IPlugin.sol";
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

function executeAutoBurn(address erc6900Account, address nftContract, uint256 tokenId) external onlyUnburntNFT(erc6900Account, nftContract, tokenId) {
    address owner = IERC721Burnable(nftContract).ownerOf(tokenId);
    require(owner == erc6900Account, "The modular account must own the NFT");
    require(block.timestamp >= _lastClaimTimestamp[nftContract][tokenId] + AUTO_BURN_DELAY, "Auto-burn delay has not passed");
    
    _burntNFTSet[erc6900Account].add(tokenId);
    IERC721Burnable(nftContract).safeTransferFrom(erc6900Account, address(this), tokenId);
    IERC721Burnable(nftContract).burn(tokenId);
    
    emit NFTBurnt(erc6900Account, nftContract, tokenId);
}

    function getBurntNFTCount(address modularAccountAddress) external view returns (uint256) {
        EnumerableSet.UintSet storage burntNFTSet = _burntNFTSet[modularAccountAddress];
        return burntNFTSet.length();
    }

    function addToBurntNFTSet(address modularAccountAddress, address nftContract, uint256 tokenId) external onlyUnburntNFT(modularAccountAddress, nftContract, tokenId) {
        _burntNFTSet[modularAccountAddress].add(tokenId);        
        IERC721Burnable(nftContract).safeTransferFrom(modularAccountAddress, address(0), tokenId);
        emit NFTBurnt(modularAccountAddress, nftContract, tokenId);
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

    function updateLastClaimTimestamp(address modularAccountAddress, address nftContract, uint256 tokenId) external {
        _lastClaimTimestamp[nftContract][tokenId] = block.timestamp;
    }

    modifier onlyUnburntNFT(address modularAccountAddress, address nftContract, uint256 tokenId) {
        require(!_burntNFTSet[modularAccountAddress].contains(tokenId), "NFT is already burnt");
        _;
    }
}
