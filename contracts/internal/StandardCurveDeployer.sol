// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {StandardCurve} from "./StandardCurve.sol";
contract StandardCurveDeployer {
    address public immutable factory;
    uint256 public constant KIND=2;
    error Unauthorized();
    constructor(address factory_){if(factory_.code.length==0)revert Unauthorized();factory=factory_;}
    function deploy() external returns(address){if(msg.sender!=factory)revert Unauthorized();return address(new StandardCurve(factory));}
}
