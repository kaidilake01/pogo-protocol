// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {StandaloneToken} from "../v4/StandaloneToken.sol";

/// @notice Standalone ERC20. The immutable pool reserves Pancake's CREATE2 address before the pair exists.
contract StandardLaunchToken is StandaloneToken {
    constructor(address factory_) StandaloneToken(factory_) {}
    function reservePair(address p) external override {
        if(msg.sender!=pool||launchPair!=address(0)||p==address(0))revert Unauthorized();
        launchPair=p;
    }
}
