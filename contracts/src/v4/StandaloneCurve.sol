// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {MultiAssetCurve} from "../v3/MultiAssetCurve.sol";

contract StandaloneCurve is MultiAssetCurve {
    address private immutable launchFactory;
    constructor(address factory_) {
        if(factory_.code.length==0)revert InvalidConfig();
        launchFactory=factory_;initialized=false;
    }
    function initialize(Init calldata p) public override {
        if(msg.sender!=launchFactory)revert InvalidConfig();
        super.initialize(p);
    }
}
