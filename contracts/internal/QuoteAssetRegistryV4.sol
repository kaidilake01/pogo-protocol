// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "./QuoteAssetRegistryV3.sol";

/// @notice Changes only NEW launch targets; oracle configuration stays in the existing registry.
/// Existing pools freeze their target and do not depend on this switch after creation.
contract QuoteAssetRegistryV4 is Ownable2Step {
    uint256 public constant CURVE_VERSION = 5;
    uint256 public constant STANDARD_TARGET_BNB = 18 ether;
    uint256 public constant TEST_TARGET_BNB = 0.1 ether;
    QuoteAssetRegistry public immutable sourceRegistry;
    uint256 public launchTargetBNB;
    error InvalidTarget();
    error InvalidRegistry();
    event LaunchTargetChanged(uint256 previousTarget, uint256 nextTarget);

    constructor(address owner_, address source_, uint256 target_) Ownable(owner_) {
        if (source_.code.length == 0 || QuoteAssetRegistryV3(source_).CURVE_VERSION() != 5
            || QuoteAssetRegistry(source_).owner() != owner_) revert InvalidRegistry();
        sourceRegistry = QuoteAssetRegistry(source_);
        _setTarget(target_);
    }

    function setLaunchTargetBNB(uint256 target_) external onlyOwner { _setTarget(target_); }
    function _setTarget(uint256 target_) private {
        if (target_ != STANDARD_TARGET_BNB && target_ != TEST_TARGET_BNB) revert InvalidTarget();
        emit LaunchTargetChanged(launchTargetBNB, target_);
        launchTargetBNB = target_;
    }

    function assetCount() external view returns (uint256) { return sourceRegistry.assetCount(); }
    function assetAt(uint256 index) external view returns (address) { return sourceRegistry.assetAt(index); }
    function assets(address asset) external view returns (address, bytes4, uint32, uint8, uint8, uint8, bool) {
        return sourceRegistry.assets(asset);
    }
    function priceUsd(address asset) external view returns (uint256, uint256) { return sourceRegistry.priceUsd(asset); }
    function configHash(address asset) public view returns (bytes32) {
        return keccak256(abi.encode(sourceRegistry.configHash(asset), block.chainid, address(this), launchTargetBNB, CURVE_VERSION));
    }
    function quoteLaunch(address asset) external view returns (QuoteAssetRegistry.LaunchQuote memory q) {
        q = sourceRegistry.quoteLaunch(asset);
        (,,, uint8 decimals,,,) = sourceRegistry.assets(asset);
        q.target = asset == address(0) ? launchTargetBNB :
            Math.mulDiv(q.bnbUsd, launchTargetBNB * 10 ** decimals, q.assetUsd * 1 ether, Math.Rounding.Ceil);
        q.virtualQuote = Math.mulDiv(q.target, 25, 73, Math.Rounding.Ceil);
        if (q.virtualQuote < 1e6 || q.target > type(uint112).max) revert InvalidTarget();
        q.configHash = configHash(asset);
    }
}
