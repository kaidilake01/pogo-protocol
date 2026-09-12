// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IMiningFunding {
    function releaseMiningReward(address recipient, uint256 amount) external;
    function stakingPriceUSD() external view returns(uint256);
}
interface IMiningDividends { function syncStake(address account) external; }

/// @notice Standalone, finite rewards funded by unsold tokens held in the graduated curve.
/// No owner, minting, upgrades, or principal recovery. Unissued rewards never earn dividends.
contract LaunchMining is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant DURATION = 30 days;
    uint256 public constant LOCK_DURATION = 6 hours;
    uint256 public constant LOCK_WEIGHT = 5;
    uint256 private constant SCALE = 1e36;
    IERC20 public immutable token;
    address public immutable vault;
    address public immutable fundingPool;
    uint256 public rewardBudget;
    uint256 public startedAt;
    uint256 public activeSeconds;
    uint256 public checkpointAt;
    uint256 public finishedAt;
    uint256 public scheduledRewards;
    uint256 public distributedRewards;
    uint256 public constant unallocatedRewards = 0;
    uint256 public claimedRewards;
    uint256 public rewardPerWeight;
    uint256 public totalStaked;
    uint256 public totalWeight;
    uint256 public totalFlexible;
    uint256 public totalLocked;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public flexibleBalance;
    mapping(address => uint256) public lockedBalance;
    mapping(address => uint256) public weightOf;
    mapping(address => uint256) public paid;
    mapping(address => uint256) public credit;
    mapping(address => uint256) public entryCostUSD;
    mapping(address => uint256) public unpricedBalance;
    mapping(address => uint256) public flexibleCostUSD;
    mapping(address => uint256) public flexibleUnpricedBalance;
    struct Lock { uint256 amount; uint64 unlockAt; uint256 costUSD; }
    mapping(address => Lock[]) public locks;
    address[] public participants;
    mapping(address => bool) private registered;
    error Unauthorized(); error InvalidAmount(); error Inactive(); error Locked(); error InvalidConfig();
    event MiningActivated(uint256 rewards, uint256 activatedAt, uint256 activeDuration);
    event Staked(address indexed account, uint256 amount, bool locked, uint256 positionId, uint256 unlockAt, uint256 costUSD);
    event Withdrawn(address indexed account, uint256 amount, bool locked, uint256 positionId);
    event RewardPaid(address indexed account, uint256 amount);
    event RewardDeferred(address indexed account);

    constructor(address token_, address vault_, address fundingPool_) {
        if(token_.code.length == 0 || vault_.code.length == 0 || fundingPool_.code.length == 0) revert InvalidConfig();
        token = IERC20(token_); vault = vault_; fundingPool = fundingPool_;
    }
    function activate(uint256 budget) external {
        if(msg.sender != fundingPool) revert Unauthorized();
        if(startedAt != 0 || budget == 0 || token.balanceOf(fundingPool) < budget) revert InvalidConfig();
        rewardBudget = budget; startedAt = block.timestamp; checkpointAt = block.timestamp;
        emit MiningActivated(budget, startedAt, DURATION);
    }
    function lockCount(address account) external view returns(uint256) { return locks[account].length; }
    function participantCount() external view returns(uint256) { return participants.length; }
    /// @notice Accumulated emission time at the current checkpoint or a later timestamp.
    function activeSecondsAt(uint256 timestamp) public view returns(uint256) {
        if(startedAt == 0) return 0;
        if(totalWeight == 0 || timestamp <= checkpointAt) return activeSeconds;
        return activeSeconds + Math.min(timestamp-checkpointAt, DURATION-activeSeconds);
    }
    /// @notice Projected finish while occupied, zero while paused, actual finish once complete.
    function endsAt() external view returns(uint256) {
        if(finishedAt != 0) return finishedAt;
        if(startedAt == 0 || totalWeight == 0) return 0;
        return checkpointAt + DURATION-activeSeconds;
    }
    function scheduledAt(uint256 timestamp) public view returns(uint256) {
        return Math.mulDiv(rewardBudget, activeSecondsAt(timestamp), DURATION);
    }
    function currentRewardPerWeight() public view returns(uint256) {
        if(totalWeight == 0) return rewardPerWeight;
        return rewardPerWeight + Math.mulDiv(scheduledAt(block.timestamp) - scheduledRewards, SCALE, totalWeight);
    }
    function earned(address account) public view returns(uint256) {
        return credit[account] + Math.mulDiv(weightOf[account], currentRewardPerWeight() - paid[account], SCALE);
    }
    function _update(address account) private {
        uint256 elapsed = activeSecondsAt(block.timestamp);
        if(elapsed == DURATION && activeSeconds < DURATION) finishedAt = checkpointAt + DURATION-activeSeconds;
        activeSeconds = elapsed; checkpointAt = block.timestamp;
        uint256 scheduled = Math.mulDiv(rewardBudget, elapsed, DURATION);
        uint256 amount = scheduled - scheduledRewards;
        scheduledRewards = scheduled;
        if(totalWeight != 0) { rewardPerWeight += Math.mulDiv(amount, SCALE, totalWeight); distributedRewards += amount; }
        credit[account] += Math.mulDiv(weightOf[account], rewardPerWeight - paid[account], SCALE);
        paid[account] = rewardPerWeight;
    }
    function stake(uint256 amount, bool locked_) external nonReentrant {
        if(startedAt == 0 || activeSecondsAt(block.timestamp) >= DURATION) revert Inactive();
        if(amount == 0) revert InvalidAmount();
        _update(msg.sender);
        uint256 before_ = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        if(token.balanceOf(address(this)) - before_ != amount) revert InvalidAmount();
        balanceOf[msg.sender] += amount; totalStaked += amount;
        if(!registered[msg.sender]) { registered[msg.sender] = true; participants.push(msg.sender); }
        uint256 costUSD;
        // Entry valuation is informational only. Oracle failure cannot prevent staking or exits.
        try IMiningFunding(fundingPool).stakingPriceUSD() returns(uint256 priceUSD) {
            costUSD = Math.mulDiv(amount, priceUSD, 1e18);
        } catch {}
        entryCostUSD[msg.sender] += costUSD;
        if(costUSD == 0) unpricedBalance[msg.sender] += amount;
        uint256 weight = amount * (locked_ ? LOCK_WEIGHT : 1);
        weightOf[msg.sender] += weight; totalWeight += weight;
        uint256 positionId; uint256 unlockAt;
        if(locked_) {
            positionId = locks[msg.sender].length; unlockAt = block.timestamp + LOCK_DURATION;
            locks[msg.sender].push(Lock(amount, uint64(unlockAt), costUSD));
            lockedBalance[msg.sender] += amount; totalLocked += amount;
        } else {
            flexibleBalance[msg.sender] += amount; totalFlexible += amount;
            flexibleCostUSD[msg.sender] += costUSD;
            if(costUSD == 0) flexibleUnpricedBalance[msg.sender] += amount;
        }
        IMiningDividends(vault).syncStake(msg.sender);
        emit Staked(msg.sender, amount, locked_, positionId, unlockAt, costUSD);
        _tryClaim(msg.sender);
    }
    function withdrawFlexible(uint256 amount) external nonReentrant {
        if(amount == 0 || amount > flexibleBalance[msg.sender]) revert InvalidAmount();
        _update(msg.sender);
        uint256 cost = Math.mulDiv(flexibleCostUSD[msg.sender], amount, flexibleBalance[msg.sender]);
        uint256 unpriced = Math.mulDiv(flexibleUnpricedBalance[msg.sender], amount, flexibleBalance[msg.sender]);
        flexibleCostUSD[msg.sender] -= cost; entryCostUSD[msg.sender] -= cost;
        flexibleUnpricedBalance[msg.sender] -= unpriced; unpricedBalance[msg.sender] -= unpriced;
        flexibleBalance[msg.sender] -= amount; totalFlexible -= amount;
        _withdraw(amount, false, 0);
    }
    function withdrawLocked(uint256 positionId, uint256 amount) external nonReentrant {
        if(positionId >= locks[msg.sender].length) revert InvalidAmount();
        Lock storage position = locks[msg.sender][positionId];
        if(block.timestamp < position.unlockAt) revert Locked();
        if(amount == 0 || amount > position.amount) revert InvalidAmount();
        _update(msg.sender);
        uint256 cost = Math.mulDiv(position.costUSD, amount, position.amount);
        if(position.costUSD == 0) unpricedBalance[msg.sender] -= amount;
        position.costUSD -= cost; entryCostUSD[msg.sender] -= cost;
        position.amount -= amount; lockedBalance[msg.sender] -= amount; totalLocked -= amount;
        _withdraw(amount, true, positionId);
    }
    function _withdraw(uint256 amount, bool locked_, uint256 positionId) private {
        balanceOf[msg.sender] -= amount; totalStaked -= amount;
        uint256 weight = amount * (locked_ ? LOCK_WEIGHT : 1);
        weightOf[msg.sender] -= weight; totalWeight -= weight;
        token.safeTransfer(msg.sender, amount);
        IMiningDividends(vault).syncStake(msg.sender);
        emit Withdrawn(msg.sender, amount, locked_, positionId);
        _tryClaim(msg.sender);
    }
    /// @notice Anyone may pay a user's accrued reward, but can never redirect it.
    function claimFor(address account) external nonReentrant { _update(account); _pay(account); }
    function claimMany(address[] calldata accounts) external nonReentrant {
        if(accounts.length > 20) revert InvalidAmount();
        for(uint256 i; i < accounts.length; i++) _tryClaim(accounts[i]);
    }
    function _tryClaim(address account) private {
        try this.payReward(account) {} catch { emit RewardDeferred(account); }
    }
    function payReward(address account) external {
        if(msg.sender != address(this)) revert Unauthorized();
        _update(account); _pay(account);
    }
    function _pay(address account) private {
        uint256 amount = credit[account];
        if(amount == 0) return;
        credit[account] = 0; claimedRewards += amount;
        if(claimedRewards > rewardBudget) revert InvalidAmount();
        IMiningFunding(fundingPool).releaseMiningReward(account, amount);
        emit RewardPaid(account, amount);
    }
}

/// @notice A permissionless deployer. The calling curve becomes the sole funding source.
contract LaunchMiningDeployer {
    function deploy(address token, address vault) external returns(address) {
        return address(new LaunchMining(token, vault, msg.sender));
    }
}
