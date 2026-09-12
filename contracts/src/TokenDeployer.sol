// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {StandardLaunchToken} from "./LaunchToken.sol";
contract StandardTokenDeployer {
    address public immutable factory;
    uint256 public constant KIND=1;
    error Unauthorized();
    constructor(address factory_){if(factory_.code.length==0)revert Unauthorized();factory=factory_;}
    function initCodeHash() public view returns(bytes32){return keccak256(abi.encodePacked(type(StandardLaunchToken).creationCode,abi.encode(factory)));}
    function predict(bytes32 salt) external view returns(address){return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),address(this),salt,initCodeHash())))));}
    function deploy(bytes32 salt) external returns(address){if(msg.sender!=factory)revert Unauthorized();return address(new StandardLaunchToken{salt:salt}(factory));}
}
