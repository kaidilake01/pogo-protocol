// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IQuoteFeed {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}
interface IAtlasMultiQuote {
    struct Snapshot { uint80 price; uint48 aggregatedTs; uint48 onchainTs; }
    function fetch(bytes4 feedId) external view returns (Snapshot memory);
    function decimals() external view returns (uint8);
}

/// @notice Prices set NEW launch terms only. An existing curve never depends on this registry to trade or graduate.
/// Stock feeds must quote the actual settlement token, including its issuer's share adjustment, in USD.
contract QuoteAssetRegistry is Ownable2Step {
    uint256 public constant TARGET_BNB = 10 ether;
    struct Asset {
        address feed;
        bytes4 feedId;
        uint32 maxAge;
        uint8 assetDecimals;
        uint8 feedDecimals;
        uint8 kind; // 0: Chainlink, 1: Atlas single, 2: Atlas multi
        bool enabled;
    }
    struct LaunchQuote {
        uint256 target;
        uint256 virtualQuote;
        uint256 assetUsd;
        uint256 bnbUsd;
        uint256 assetUpdatedAt;
        uint256 bnbUpdatedAt;
        bytes32 configHash;
    }
    mapping(address => Asset) public assets;
    address[] private catalog;
    mapping(address => bool) private listed;
    error InvalidAsset();
    error InvalidPrice(address asset);
    error StalePrice(address asset);
    event AssetConfigured(address indexed asset, Asset config);

    constructor(address owner_) Ownable(owner_) {}

    function assetCount() external view returns (uint256) { return catalog.length; }
    function assetAt(uint256 index) external view returns (address) { return catalog[index]; }

    /// @dev Reads from this contract, so an EOA-only oracle cannot accidentally be enabled.
    function configure(address asset, Asset calldata config) external onlyOwner {
        if (config.feed.code.length == 0 || config.kind > 2 || config.maxAge == 0 || config.maxAge > 2 days
            || config.assetDecimals < 6 || config.assetDecimals > 18 || config.feedDecimals > 18
            || (config.kind != 2 && config.feedId != bytes4(0))
            || (config.kind == 2 && config.feedId == bytes4(0))) revert InvalidAsset();
        if (asset == address(0)) {
            if (config.assetDecimals != 18) revert InvalidAsset();
        } else if (asset.code.length == 0 || IERC20Metadata(asset).decimals() != config.assetDecimals) {
            revert InvalidAsset();
        }
        if (IQuoteFeed(config.feed).decimals() != config.feedDecimals) revert InvalidAsset();
        assets[asset] = config;
        if (config.enabled) priceUsd(asset);
        if (!listed[asset]) { listed[asset] = true; catalog.push(asset); }
        emit AssetConfigured(asset, config);
    }

    function setEnabled(address asset, bool enabled) external onlyOwner {
        if (!listed[asset]) revert InvalidAsset();
        assets[asset].enabled = enabled;
        if (enabled) priceUsd(asset);
        emit AssetConfigured(asset, assets[asset]);
    }

    /// @return price USD per whole quote token, scaled by 1e18.
    /// @return updatedAt Aggregation time for Atlas, update time for Chainlink.
    function priceUsd(address asset) public view returns (uint256 price, uint256 updatedAt) {
        Asset memory a = assets[asset];
        if (a.feed == address(0)) revert InvalidAsset();
        uint256 onchainAt;
        if (a.kind == 2) {
            IAtlasMultiQuote.Snapshot memory s = IAtlasMultiQuote(a.feed).fetch(a.feedId);
            price = uint256(s.price);
            updatedAt = s.aggregatedTs;
            onchainAt = s.onchainTs;
        } else {
            (uint80 round, int256 answer, uint256 started, uint256 updated, uint80 answered) =
                IQuoteFeed(a.feed).latestRoundData();
            if (answer <= 0 || round == 0 || answered < round) revert InvalidPrice(asset);
            price = uint256(answer);
            updatedAt = a.kind == 1 ? started : updated;
            onchainAt = updated;
        }
        if (price == 0 || price > 1e36) revert InvalidPrice(asset);
        if (updatedAt == 0 || updatedAt > onchainAt || onchainAt > block.timestamp
            || block.timestamp - updatedAt > a.maxAge) revert StalePrice(asset);
        price *= 10 ** (18 - a.feedDecimals);
    }

    function configHash(address asset) public view virtual returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), asset, assets[asset], assets[address(0)], TARGET_BNB));
    }

    /// @notice Freeze these quantities in the curve at creation; later market movement never moves its finish line.
    function quoteLaunch(address asset) public view virtual returns (LaunchQuote memory q) {
        Asset memory a = assets[asset];
        if (!a.enabled || !assets[address(0)].enabled) revert InvalidAsset();
        (q.bnbUsd, q.bnbUpdatedAt) = priceUsd(address(0));
        (q.assetUsd, q.assetUpdatedAt) = asset == address(0)
            ? (q.bnbUsd, q.bnbUpdatedAt) : priceUsd(asset);
        q.target = asset == address(0) ? TARGET_BNB :
            Math.mulDiv(q.bnbUsd * 10, 10 ** a.assetDecimals, q.assetUsd, Math.Rounding.Ceil);
        // Constant-product curve opens at a 2.5 BNB-equivalent fully diluted valuation.
        // 80% of the fixed supply sells before graduation, modulo integer rounding.
        q.virtualQuote = q.target / 4;
        if (q.virtualQuote < 1e6 || q.target > type(uint112).max) revert InvalidAsset();
        q.configHash = configHash(asset);
    }
}
