// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "./QuoteAssetRegistryV3.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Original FOUR-matched opening reserves; new launches graduate at 6.666 BNB equivalent.
contract QuoteAssetRegistryV5 {
    uint256 public constant CURVE_VERSION=6;
    uint256 public constant LAUNCH_TARGET_BNB=6.666 ether;
    QuoteAssetRegistry public immutable sourceRegistry;
    error InvalidConfig();
    constructor(address source_) {
        if(source_.code.length==0||QuoteAssetRegistryV3(source_).CURVE_VERSION()!=5
            ||QuoteAssetRegistryV3(source_).STANDARD_TARGET_BNB()!=18 ether)revert InvalidConfig();
        QuoteAssetRegistry.LaunchQuote memory q=QuoteAssetRegistry(source_).quoteLaunch(address(0));
        if(q.target!=18 ether)revert InvalidConfig();
        sourceRegistry=QuoteAssetRegistry(source_);
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
        q.target=Math.mulDiv(q.target,1111,3000,Math.Rounding.Ceil);
        q.configHash=configHash(asset);
    }
}
