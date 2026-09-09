// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice New launches open near FLAP's current ~5.546 BNB FDV, with an independent 10 BNB net reserve target.
/// Existing curves have frozen quantities and are unaffected by replacing a factory registry.
contract QuoteAssetRegistryV2 is QuoteAssetRegistry {
    uint256 public constant INITIAL_FDV_BNB = 5.5 ether;
    constructor(address owner_) QuoteAssetRegistry(owner_) {}

    function configHash(address asset) public view override returns(bytes32) {
        return keccak256(abi.encode(super.configHash(asset), INITIAL_FDV_BNB));
    }
    function quoteLaunch(address asset) public view override returns(LaunchQuote memory q) {
        q=super.quoteLaunch(asset);
        q.virtualQuote=Math.mulDiv(q.target,INITIAL_FDV_BNB,TARGET_BNB,Math.Rounding.Ceil);
    }
}
