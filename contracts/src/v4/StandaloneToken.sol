// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LaunchTokenV3} from "../v3/LaunchTokenV3.sol";

/// @notice Full ERC20 runtime, with no delegatecall or upgrade mechanism.
/// Ownership is relinquished in the constructor. Only one-time atomic factory initialization remains.
contract StandaloneToken is LaunchTokenV3, Ownable {
    address private immutable launchFactory;
    constructor(address factory_) Ownable(factory_) {
        if(factory_.code.length==0)revert InvalidConfig();
        launchFactory=factory_;initialized=false;
        _transferOwnership(address(0));
    }
    function initialize(Init calldata p) public override {
        if(msg.sender!=launchFactory)revert Unauthorized();
        super.initialize(p);
    }
}
