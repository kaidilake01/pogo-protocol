// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StandaloneVault} from "./StandaloneVault.sol";
import {LaunchMining} from "./LaunchMining.sol";

/// @notice Wallet plus staked principal keeps the original per-person dividend eligibility.
contract MiningRevenueVault is StandaloneVault {
    address public stakingPool;
    constructor(address factory_) StandaloneVault(factory_) {}
    function setStakingPool(address staking_) external {
        if(msg.sender != pool || stakingPool != address(0) || staking_.code.length == 0
            || LaunchMining(staking_).fundingPool() != pool || address(LaunchMining(staking_).token()) != token
            || LaunchMining(staking_).vault() != address(this)) revert Unauthorized();
        stakingPool = staking_;
    }
    function eligible(address who) public view override returns(bool) {
        return who != stakingPool && super.eligible(who);
    }
    function _beneficialBalance(address who, uint256 wallet) private view returns(uint256) {
        return wallet + (stakingPool == address(0) || !eligible(who) ? 0 : LaunchMining(stakingPool).balanceOf(who));
    }
    function syncBalances(address from,uint256 fromBalance,address to,uint256 toBalance) external override {
        if(msg.sender != token) revert Unauthorized();
        _sync(from, _beneficialBalance(from, fromBalance));
        if(to != from) _sync(to, _beneficialBalance(to, toBalance));
    }
    function syncStake(address account) external {
        if(msg.sender != stakingPool) revert Unauthorized();
        _sync(account, _beneficialBalance(account, IERC20(token).balanceOf(account)));
    }
}

contract MiningVaultDeployer {
    address public immutable factory;
    uint256 public constant KIND = 3;
    error Unauthorized();
    constructor(address factory_) { if(factory_.code.length == 0) revert Unauthorized(); factory = factory_; }
    function deploy() external returns(address) {
        if(msg.sender != factory) revert Unauthorized();
        return address(new MiningRevenueVault(factory));
    }
}
