// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {RevenueVault} from "../v3/RevenueVault.sol";
import {LaunchTypes} from "../v3/LaunchTypes.sol";

contract StandaloneVault is RevenueVault {
    address private immutable launchFactory;
    constructor(address factory_) {
        if(factory_.code.length==0)revert InvalidConfig();
        launchFactory=factory_;initialized=false;
    }
    function initialize(address token_,address creator_,address pool_,address quote_,address router_,LaunchTypes.Tax calldata t) public override {
        if(msg.sender!=launchFactory)revert Unauthorized();
        super.initialize(token_,creator_,pool_,quote_,router_,t);
    }
}
