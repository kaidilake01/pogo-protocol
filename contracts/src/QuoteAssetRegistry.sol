// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {QuoteAssetRegistry} from "../internal/QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "../internal/QuoteAssetRegistryV3.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Independent graduation target with unchanged original opening reserves.
/// A new registry must be selected by the factory to switch test/production terms.
/// Existing curves snapshot their terms and never inherit a later factory switch.
contract QuoteAssetRegistryV7 {
    uint256 public constant CURVE_VERSION=6;
    uint256 public immutable LAUNCH_TARGET_BNB;
    QuoteAssetRegistry public immutable sourceRegistry;
    error InvalidConfig();
    constructor(address source_,uint256 target_) {
        if(source_.code.length==0 || (target_!=0.01 ether && target_!=0.1 ether && target_!=6.666 ether)
            || QuoteAssetRegistryV3(source_).CURVE_VERSION()!=5
            || QuoteAssetRegistryV3(source_).STANDARD_TARGET_BNB()!=18 ether) revert InvalidConfig();
        if(QuoteAssetRegistry(source_).quoteLaunch(address(0)).target!=18 ether) revert InvalidConfig();
        sourceRegistry=QuoteAssetRegistry(source_); LAUNCH_TARGET_BNB=target_;
    }
    function owner() external view returns(address) { return sourceRegistry.owner(); }
    function assetCount() external view returns(uint256) { return sourceRegistry.assetCount(); }
    function assetAt(uint256 index) external view returns(address) { return sourceRegistry.assetAt(index); }
    function assets(address asset) external view returns(address,bytes4,uint32,uint8,uint8,uint8,bool) { return sourceRegistry.assets(asset); }
    function priceUsd(address asset) external view returns(uint256,uint256) { return sourceRegistry.priceUsd(asset); }
    function configHash(address asset) public view returns(bytes32) {
        return keccak256(abi.encode(sourceRegistry.configHash(asset),block.chainid,address(this),LAUNCH_TARGET_BNB,CURVE_VERSION));
    }
    function quoteLaunch(address asset) external view returns(QuoteAssetRegistry.LaunchQuote memory q) {
        q=sourceRegistry.quoteLaunch(asset);
        q.target=Math.mulDiv(q.target,LAUNCH_TARGET_BNB,18 ether,Math.Rounding.Ceil);
        q.configHash=configHash(asset);
    }
}
