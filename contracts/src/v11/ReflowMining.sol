// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IReflowFunding {
    function releaseMiningReward(address recipient, uint256 amount) external;
    function stakingPriceUSD() external view returns(uint256);
    function pair() external view returns(address);
}
interface IReflowDividends { function syncStake(address account) external; }
interface IReflowPair is IERC20 {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function getReserves() external view returns(uint112,uint112,uint32);
}

/// @notice Three independent finite reward budgets. Empty time never earns rewards.
/// No owner, upgrades, minting, recovery, or admission of non-canonical LP assets.
contract ReflowMining is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant VERSION = 11;
    uint256 public constant DURATION = 90 days;
    uint256 public constant LOCK_DURATION = 24 hours;
    uint256 public constant EARLY_EXIT_BPS = 1000;
    uint256 private constant SCALE = 1e36;
    IERC20 public immutable token;
    address public immutable vault;
    address public immutable fundingPool;
    address public immutable penaltyRecipient;
    address public lpToken;
    uint256 public rewardBudget;
    uint256 public startedAt;
    uint256 public claimedRewards;
    struct Pool {
        uint256 budget; uint256 totalStaked; uint256 activeSeconds; uint256 checkpointAt;
        uint256 finishedAt; uint256 scheduled; uint256 claimed; uint256 rewardPerToken;
    }
    Pool[3] private pools;
    mapping(uint8 => mapping(address => uint256)) public stakeOf;
    mapping(uint8 => mapping(address => uint256)) private paid;
    mapping(uint8 => mapping(address => uint256)) private credit;
    mapping(uint8 => mapping(address => uint256)) public costUSD;
    mapping(uint8 => mapping(address => uint256)) public unpriced;
    struct Lock { uint256 amount; uint64 unlockAt; uint256 costUSD; bool unpriced; }
    mapping(address => Lock[]) public locks;
    mapping(address => Lock[]) public lpLocks;
    address[] public participants;
    mapping(address => bool) private registered;
    error Unauthorized(); error InvalidAmount(); error Inactive(); error Locked(); error InvalidConfig();
    event MiningActivated(uint256 rewards,address indexed lpToken,uint256 activeDuration);
    event Staked(address indexed account,uint8 indexed poolId,uint256 amount,uint256 positionId,uint256 unlockAt);
    event Withdrawn(address indexed account,uint8 indexed poolId,uint256 amount,uint256 positionId);
    event RewardPaid(address indexed account,uint8 indexed poolId,uint256 amount);
    event RewardDeferred(address indexed account);
    event EarlyExitPenalty(address indexed account,uint8 indexed poolId,address indexed recipient,address asset,uint256 amount);

    constructor(address token_,address vault_,address fundingPool_) {
        if(token_.code.length==0||vault_.code.length==0||fundingPool_.code.length==0)revert InvalidConfig();
        token=IERC20(token_);vault=vault_;fundingPool=fundingPool_;
        penaltyRecipient=address(0xdead);
    }
    function activate(uint256 budget,address pair_) external {
        if(msg.sender!=fundingPool)revert Unauthorized();
        if(startedAt!=0||budget<100||token.balanceOf(fundingPool)<budget||pair_.code.length==0
            ||IReflowFunding(fundingPool).pair()!=pair_)revert InvalidConfig();
        if(IReflowPair(pair_).token0()!=address(token)&&IReflowPair(pair_).token1()!=address(token))revert InvalidConfig();
        lpToken=pair_;rewardBudget=budget;startedAt=block.timestamp;
        pools[0].budget=budget/100;pools[1].budget=Math.mulDiv(budget,9,100);
        pools[2].budget=budget-pools[0].budget-pools[1].budget;
        for(uint8 i;i<3;i++)pools[i].checkpointAt=block.timestamp;
        emit MiningActivated(budget,pair_,DURATION);
    }
    function _check(uint8 id) private pure { if(id>2)revert InvalidConfig(); }
    function balanceOf(address account) external view returns(uint256) { return stakeOf[0][account]+stakeOf[1][account]; }
    function lockCount(address account) external view returns(uint256) { return locks[account].length; }
    function lpLockCount(address account) external view returns(uint256) { return lpLocks[account].length; }
    function participantCount() external view returns(uint256) { return participants.length; }
    function _elapsed(Pool memory p) private view returns(uint256) {
        return p.activeSeconds+(startedAt!=0&&p.totalStaked!=0?Math.min(block.timestamp-p.checkpointAt,DURATION-p.activeSeconds):0);
    }
    /// @notice A current projection, including elapsed occupied time since the last transaction.
    function poolState(uint8 id) public view returns(Pool memory p) {
        _check(id);p=pools[id];uint256 elapsed=_elapsed(p);
        if(elapsed==DURATION&&p.activeSeconds<DURATION)p.finishedAt=p.checkpointAt+DURATION-p.activeSeconds;
        uint256 scheduled=Math.mulDiv(p.budget,elapsed,DURATION);
        if(p.totalStaked!=0)p.rewardPerToken+=Math.mulDiv(scheduled-p.scheduled,SCALE,p.totalStaked);
        p.activeSeconds=elapsed;p.checkpointAt=block.timestamp;p.scheduled=scheduled;
    }
    function poolEndsAt(uint8 id) external view returns(uint256) {
        Pool memory p=poolState(id);
        return p.finishedAt!=0?p.finishedAt:startedAt==0||p.totalStaked==0?0:block.timestamp+DURATION-p.activeSeconds;
    }
    function earnedIn(uint8 id,address account) public view returns(uint256) {
        Pool memory p=poolState(id);
        return credit[id][account]+Math.mulDiv(stakeOf[id][account],p.rewardPerToken-paid[id][account],SCALE);
    }
    function earned(address account) external view returns(uint256) { return earnedIn(0,account)+earnedIn(1,account)+earnedIn(2,account); }
    function _update(uint8 id,address account) private {
        Pool memory p=poolState(id);pools[id]=p;
        credit[id][account]+=Math.mulDiv(stakeOf[id][account],p.rewardPerToken-paid[id][account],SCALE);
        paid[id][account]=p.rewardPerToken;
    }
    /// @notice Single-token entry point, retaining the legacy vault/transaction interface.
    function stake(uint256 amount,bool locked_) external nonReentrant { _stake(locked_?1:0,amount); }
    function stakeLP(uint256 amount) external nonReentrant { _stake(2,amount); }
    function _stake(uint8 id,uint256 amount) private {
        if(startedAt==0||_elapsed(pools[id])>=DURATION)revert Inactive();
        if(amount==0)revert InvalidAmount();
        _update(id,msg.sender);
        IERC20 asset=id==2?IERC20(lpToken):token;
        uint256 before_=asset.balanceOf(address(this));asset.safeTransferFrom(msg.sender,address(this),amount);
        if(asset.balanceOf(address(this))-before_!=amount)revert InvalidAmount();
        stakeOf[id][msg.sender]+=amount;pools[id].totalStaked+=amount;
        if(!registered[msg.sender]){registered[msg.sender]=true;participants.push(msg.sender);}
        uint256 cost;
        try this.assetPriceUSD(id) returns(uint256 price){cost=Math.mulDiv(amount,price,1e18);}catch{}
        costUSD[id][msg.sender]+=cost;if(cost==0)unpriced[id][msg.sender]+=amount;
        uint256 positionId;uint256 unlockAt;
        if(id>0){
            Lock[] storage positions=id==1?locks[msg.sender]:lpLocks[msg.sender];
            positionId=positions.length;unlockAt=block.timestamp+LOCK_DURATION;
            positions.push(Lock(amount,uint64(unlockAt),cost,cost==0));
        }
        if(id<2)IReflowDividends(vault).syncStake(msg.sender);
        emit Staked(msg.sender,id,amount,positionId,unlockAt);_tryClaim(msg.sender);
    }
    /// @notice Valuation only; never used to size rewards or gate principal exits.
    function assetPriceUSD(uint8 id) external view returns(uint256) {
        _check(id);uint256 price=IReflowFunding(fundingPool).stakingPriceUSD();
        if(id<2)return price;
        (uint112 r0,uint112 r1,)=IReflowPair(lpToken).getReserves();
        uint256 reserve=IReflowPair(lpToken).token0()==address(token)?r0:r1;
        return Math.mulDiv(reserve*2,price,IReflowPair(lpToken).totalSupply());
    }
    function withdrawFlexible(uint256 amount) external nonReentrant { _withdrawOpen(0,amount); }
    function _withdrawOpen(uint8 id,uint256 amount) private {
        uint256 balance=stakeOf[id][msg.sender];
        if(amount==0||amount>balance)revert InvalidAmount();_update(id,msg.sender);
        costUSD[id][msg.sender]-=Math.mulDiv(costUSD[id][msg.sender],amount,balance);
        unpriced[id][msg.sender]-=Math.mulDiv(unpriced[id][msg.sender],amount,balance);
        _withdraw(id,amount,0,0);
    }
    function withdrawLocked(uint256 positionId,uint256 amount) external nonReentrant {
        _withdrawPosition(1,positionId,amount,false);
    }
    function withdrawLP(uint256 positionId,uint256 amount) external nonReentrant { _withdrawPosition(2,positionId,amount,false); }
    /// @notice Explicit opt-in to the early exit penalty. Mature positions pay no penalty.
    function withdrawLockedEarly(uint256 positionId,uint256 amount) external nonReentrant { _withdrawPosition(1,positionId,amount,true); }
    function withdrawLPEarly(uint256 positionId,uint256 amount) external nonReentrant { _withdrawPosition(2,positionId,amount,true); }
    function _withdrawPosition(uint8 id,uint256 positionId,uint256 amount,bool allowEarly) private {
        Lock[] storage positions=id==1?locks[msg.sender]:lpLocks[msg.sender];
        if(positionId>=positions.length)revert InvalidAmount();
        Lock storage position=positions[positionId];
        bool early=block.timestamp<position.unlockAt;
        if(early&&!allowEarly)revert Locked();
        if(amount==0||amount>position.amount)revert InvalidAmount();_update(id,msg.sender);
        uint256 cost=Math.mulDiv(position.costUSD,amount,position.amount);
        if(position.unpriced)unpriced[id][msg.sender]-=amount;
        position.costUSD-=cost;costUSD[id][msg.sender]-=cost;position.amount-=amount;
        _withdraw(id,amount,positionId,early?Math.mulDiv(amount,EARLY_EXIT_BPS,10000):0);
    }
    function _withdraw(uint8 id,uint256 amount,uint256 positionId,uint256 penalty) private {
        stakeOf[id][msg.sender]-=amount;pools[id].totalStaked-=amount;
        IERC20 asset=id==2?IERC20(lpToken):token;
        asset.safeTransfer(msg.sender,amount-penalty);
        if(penalty!=0){asset.safeTransfer(penaltyRecipient,penalty);emit EarlyExitPenalty(msg.sender,id,penaltyRecipient,address(asset),penalty);}
        if(id<2)IReflowDividends(vault).syncStake(msg.sender);
        emit Withdrawn(msg.sender,id,amount,positionId);_tryClaim(msg.sender);
    }
    function claimFor(address account) external nonReentrant { _payAll(account); }
    function claimMany(address[] calldata accounts) external nonReentrant {
        if(accounts.length>20)revert InvalidAmount();for(uint256 i;i<accounts.length;i++)_tryClaim(accounts[i]);
    }
    function _tryClaim(address account) private { try this.payReward(account) {}catch{emit RewardDeferred(account);} }
    function payReward(address account) external { if(msg.sender!=address(this))revert Unauthorized();_payAll(account); }
    function _payAll(address account) private {
        for(uint8 i;i<3;i++){
            _update(i,account);uint256 amount=credit[i][account];if(amount==0)continue;
            credit[i][account]=0;pools[i].claimed+=amount;claimedRewards+=amount;
            if(pools[i].claimed>pools[i].budget||claimedRewards>rewardBudget)revert InvalidAmount();
            IReflowFunding(fundingPool).releaseMiningReward(account,amount);emit RewardPaid(account,i,amount);
        }
    }
}
contract ReflowMiningDeployer {
    function deploy(address token,address vault) external returns(address) { return address(new ReflowMining(token,vault,msg.sender)); }
}
