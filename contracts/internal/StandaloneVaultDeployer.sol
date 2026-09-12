// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {StandaloneVault} from "./StandaloneVault.sol";
contract StandaloneVaultDeployer {
    address public immutable factory;
    uint256 public constant KIND=3;
    error Unauthorized();
    constructor(address factory_){if(factory_.code.length==0)revert Unauthorized();factory=factory_;}
    function deploy() external returns(address){if(msg.sender!=factory)revert Unauthorized();return address(new StandaloneVault(factory));}
}
