// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ReflowCurve} from "./MiningCurve.sol";
contract ReflowCurveDeployer {
    address public immutable factory;
    address public immutable miningDeployer;
    uint256 public constant KIND=2;
    uint256 public constant CURVE_VERSION=11;
    error Unauthorized();
    constructor(address factory_,address miningDeployer_) {
        if(factory_.code.length==0||miningDeployer_.code.length==0)revert Unauthorized();
        factory=factory_;miningDeployer=miningDeployer_;
    }
    function deploy() external returns(address) {
        if(msg.sender!=factory)revert Unauthorized();
        return address(new ReflowCurve(factory,miningDeployer));
    }
}
