// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC7579Module} from "./IERC7579Module.sol";
import {IERC7579Account} from "./IERC7579Account.sol";

contract NFTBurnTrackingPlugin is IERC7579Module {
    using EnumerableSet for EnumerableSet.UintSet;

    string public constant NAME = "Cosmic Bots NFT Burn Tracking Plugin";
    string public constant VERSION = "1.0.0";
    string public constant AUTHOR = "Elisha Day";

    uint256 public constant MODULE_TYPE = 2; // Executor module type

    mapping(address => EnumerableSet.UintSet) private _burntNFTSet;

    event NFTBurnt(address indexed account, address indexed nftContract, uint256 indexed tokenId);

    IERC7579Account public immutable account;

    constructor(IERC7579Account _account) {
        account = _account;
    }

    function onInstall(bytes calldata) external override {
        require(msg.sender == address(account), "Only account can install");
    }

    function onUninstall(bytes calldata) external override {
        require(msg.sender == address(account), "Only account can uninstall");
    }

    function isModuleType(uint256 moduleType) external pure override returns (bool) {
        return moduleType == MODULE_TYPE;
    }

    function getModuleTypes() external pure override returns (uint256) {
        return MODULE_TYPE;
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
        require(msg.sender == address(account), "Only the account can execute auto-burn");
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(owner == address(account), "The modular account must own the NFT");
        IERC721(nftContract).transferFrom(address(account), address(0), tokenId);
        _burntNFTSet[address(account)].add(tokenId);
        emit NFTBurnt(address(account), nftContract, tokenId);
    }

    function executeFromExecutor(
        bytes32 mode,
        bytes calldata executionCalldata
    ) external override {
        require(msg.sender == address(account), "Only the account can execute");
        (address nftContract, uint256 tokenId) = abi.decode(executionCalldata, (address, uint256));
        executeAutoBurn(nftContract, tokenId);
    }
}
