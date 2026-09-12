// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice FOUR standard BNB launch economics, converted once into the selected settlement asset.
contract QuoteAssetRegistryV3 is QuoteAssetRegistry {
    uint256 public constant STANDARD_TARGET_BNB=18 ether;
    uint256 public constant CURVE_VERSION=5;
    constructor(address owner_) QuoteAssetRegistry(owner_) {}
    function configHash(address asset) public view override returns(bytes32){
        return keccak256(abi.encode(super.configHash(asset),STANDARD_TARGET_BNB,CURVE_VERSION));
    }
    function quoteLaunch(address asset) public view override returns(LaunchQuote memory q){
        q=super.quoteLaunch(asset);
        q.target=asset==address(0)?STANDARD_TARGET_BNB:
            Math.mulDiv(q.bnbUsd*18,10**assets[asset].assetDecimals,q.assetUsd,Math.Rounding.Ceil);
        // 80% sold, 20% LP and 2% seeding fee; price is continuous at graduation.
        q.virtualQuote=Math.mulDiv(q.target,25,73,Math.Rounding.Ceil);
        if(q.virtualQuote<1e6||q.target>type(uint112).max)revert InvalidAsset();
    }
}
