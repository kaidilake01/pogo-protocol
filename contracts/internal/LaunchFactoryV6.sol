// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchFactoryV5} from "./LaunchFactoryV5.sol";

/// @notice Free creation, with unchanged storage, deployment templates and trading fees.
contract LaunchFactoryV6 is LaunchFactoryV5 {
    uint256 public constant FREE_CREATION_VERSION = 1;
    function CREATION_FEE() public pure override returns (uint256) { return 0; }
}
