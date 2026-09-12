// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LaunchTypes, ILaunchTokenV3} from "./LaunchTypes.sol";
import {MultiAssetCurve} from "./MultiAssetCurve.sol";
import {IV2Router, IV2Pair, IWBNB} from "./Interfaces.sol";

interface IQuoteSwapRouter {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256,address[] calldata,address,uint256) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[] calldata,address,uint256) external;
}
interface ICumulativePair {
    function price0CumulativeLast() external view returns(uint256);
    function price1CumulativeLast() external view returns(uint256);
}
interface IUnwrap { function withdraw(uint256 amount) external; }

/// @notice Immutable per-launch tax allocation; balance-based dividends, no staking or principal deposits.
contract RevenueVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 private constant SCALE=1e36;
    address public token;
    address public creator;
    address public pool;
    address public pair;
    address public quoteAsset;
    address public router;
    LaunchTypes.Tax public tax;
    uint256 public eligibleSupply;
    uint256 public burnBudget;
    uint256 public totalBuybackBurned;
    uint256 public constant AUTOMATION_VERSION=1;
    uint256 public constant OBSERVATION_WINDOW=180;
    uint256 public priceCumulative;
    uint256 public observationAt;
    uint256 public lastAutomationAt;
    bool internal initialized;
    mapping(address=>uint256) public holderBalance;
    mapping(address=>uint256) public accPerShare;
    mapping(address=>uint256) public queued;
    mapping(address=>uint256) public totalDistributed;
    mapping(address=>uint256) public recipientCredit;
    mapping(address=>uint256) public liquidityBudget;
    mapping(address=>mapping(address=>uint256)) public paid;
    mapping(address=>mapping(address=>uint256)) public credit;
    error InvalidConfig(); error Unauthorized(); error InvalidAmount(); error TransferFailed();
    event RevenueAllocated(address indexed asset,uint256 recipient,uint256 holders,uint256 burn,uint256 liquidity);
    event RecipientPaid(address indexed asset,address indexed recipient,uint256 amount);
    event RecipientDeferred(address indexed asset,uint256 amount);
    event Claimed(address indexed holder,address indexed asset,address recipient,uint256 amount);
    event BuybackExecuted(uint256 quoteAmount,uint256 burned);
    event LiquidityAdded(uint256 quoteAmount,uint256 tokenAmount,uint256 lp);
    event AutomationRun(uint256 actions);
    event PriceObserved(uint256 timestamp);

    constructor(){initialized=true;}
    function initialize(address token_,address creator_,address pool_,address quote_,address router_,LaunchTypes.Tax calldata t) public virtual {
        if(initialized||token_==address(0)||creator_==address(0)||pool_==address(0)||router_.code.length==0||!LaunchTypes.valid(t)) revert InvalidConfig();
        initialized=true;token=token_;creator=creator_;pool=pool_;quoteAsset=quote_;router=router_;tax=t;
    }
    function validAsset(address asset) public view returns(bool){return asset==quoteAsset||asset==token;}
    function eligible(address who) public view virtual returns(bool){
        return who!=address(0)&&who!=address(0xdead)&&who!=token&&who!=address(this)&&who!=pool&&who!=pair;
    }
    function _settle(address who,address asset) private {
        credit[who][asset]+=Math.mulDiv(holderBalance[who],accPerShare[asset]-paid[who][asset],SCALE);
        paid[who][asset]=accPerShare[asset];
    }
    function _sync(address who,uint256 balance) internal {
        if(!eligible(who))return;
        _settle(who,quoteAsset);_settle(who,token);
        uint256 next=balance>=tax.minimumHolding?balance:0;
        eligibleSupply=eligibleSupply-holderBalance[who]+next;holderBalance[who]=next;
    }
    function syncBalances(address from,uint256 fromBalance,address to,uint256 toBalance) external virtual {
        if(msg.sender!=token)revert Unauthorized();
        _sync(from,fromBalance);if(to!=from)_sync(to,toBalance);
    }
    function setPair(address pair_) external {
        if(msg.sender!=token||pair!=address(0)||pair_==address(0))revert Unauthorized();
        _sync(pair_,0);pair=pair_;
    }
    function earned(address who,address asset) external view returns(uint256){
        return credit[who][asset]+Math.mulDiv(holderBalance[who],accPerShare[asset]-paid[who][asset],SCALE);
    }
    function _allocate(address asset,uint256 amount) private {
        amount+=queued[asset];
        if(eligibleSupply==0){queued[asset]=amount;return;}
        accPerShare[asset]+=Math.mulDiv(amount,SCALE,eligibleSupply);
        queued[asset]=0;totalDistributed[asset]+=amount;
    }
    function distributeQueued(address asset) external nonReentrant {
        if(!validAsset(asset)||queued[asset]==0||eligibleSupply==0)revert InvalidAmount();_allocate(asset,0);
    }
    /// @dev Only the curve notifies trading revenue. Buyback-triggered fees intentionally remain reentrant-safe:
    /// accounting is performed first, recipient attempts are isolated and cannot touch other beneficiaries' credits.
    function notifyQuote(uint256 amount) external payable {
        if(msg.sender!=pool||amount==0)revert Unauthorized();
        if(quoteAsset==address(0)){if(msg.value!=amount)revert InvalidAmount();}
        else {
            if(msg.value!=0)revert InvalidAmount();
            uint256 before_=IERC20(quoteAsset).balanceOf(address(this));
            IERC20(quoteAsset).safeTransferFrom(msg.sender,address(this),amount);
            if(IERC20(quoteAsset).balanceOf(address(this))-before_!=amount)revert InvalidAmount();
        }
        _split(quoteAsset,amount);
    }
    function depositTokenRevenue(uint256 amount) external nonReentrant {
        if(msg.sender!=token||amount==0)revert Unauthorized();
        IERC20(token).safeTransferFrom(token,address(this),amount);_split(token,amount);
    }
    function _split(address asset,uint256 amount) private {
        uint256 holders=amount*tax.holderBps/10_000;
        uint256 burn=amount*tax.burnBps/10_000;
        uint256 liquidity=amount*tax.liquidityBps/10_000;
        uint256 recipient=amount-holders-burn-liquidity;
        recipientCredit[asset]+=recipient;liquidityBudget[asset]+=liquidity;
        if(asset==token&&burn!=0){ILaunchTokenV3(token).burn(burn);totalBuybackBurned+=burn;}
        else if(asset==quoteAsset)burnBudget+=burn;
        if(holders!=0||queued[asset]!=0)_allocate(asset,holders);
        emit RevenueAllocated(asset,recipient,holders,burn,liquidity);
        _tryRecipient(asset);
    }
    // External self-call isolates a reverting, gas-consuming or blocked recipient; trades keep working.
    function _tryRecipient(address asset) private {
        if(recipientCredit[asset]==0)return;
        try this.payRecipient{gas:120_000}(asset) {} catch {emit RecipientDeferred(asset,recipientCredit[asset]);}
    }
    function payRecipient(address asset) external {
        if(msg.sender!=address(this))revert Unauthorized();
        uint256 amount=recipientCredit[asset];recipientCredit[asset]=0;
        _send(asset,tax.recipient,amount);emit RecipientPaid(asset,tax.recipient,amount);
    }
    function flushRecipient(address asset) external nonReentrant {
        if(!validAsset(asset)||recipientCredit[asset]==0)revert InvalidAmount();_tryRecipient(asset);
    }
    function claimRecipient(address asset,address recipient) external nonReentrant {
        if(msg.sender!=tax.recipient||recipient==address(0)||!validAsset(asset))revert Unauthorized();
        uint256 amount=recipientCredit[asset];if(amount==0)revert InvalidAmount();
        recipientCredit[asset]=0;_send(asset,recipient,amount);emit RecipientPaid(asset,recipient,amount);
    }
    function claim(address asset,address recipient) external nonReentrant {
        if(!validAsset(asset)||recipient==address(0))revert InvalidConfig();
        _settle(msg.sender,asset);uint256 amount=credit[msg.sender][asset];
        if(amount==0)revert InvalidAmount();credit[msg.sender][asset]=0;
        _send(asset,recipient,amount);emit Claimed(msg.sender,asset,recipient,amount);
    }
    /// @notice Creator supplies trade slippage; no arbitrary caller can spend a shared buyback budget at zero minimum.
    function executeBuyback(uint256 amount,uint256 minTokens,uint256 deadline) external nonReentrant {
        if(msg.sender!=creator)revert Unauthorized();
        _executeBuyback(amount,minTokens,deadline);
    }
    function _executeBuyback(uint256 amount,uint256 minTokens,uint256 deadline) private {
        if(amount==0||amount>burnBudget||minTokens==0||block.timestamp>deadline)revert InvalidAmount();
        burnBudget-=amount;
        uint256 before_=IERC20(token).balanceOf(address(this));
        if(pair==address(0)){
            MultiAssetCurve.BuyQuote memory q=MultiAssetCurve(pool).quoteBuy(amount);
            if(q.tokens==0)revert InvalidAmount();
            // Restore the portion the curve cannot accept, in both native and ERC-20 routes.
            burnBudget+=q.refund;
            if(quoteAsset!=address(0))IERC20(quoteAsset).forceApprove(pool,q.used);
            MultiAssetCurve(pool).buy{value:quoteAsset==address(0)?amount:0}(amount,minTokens,deadline,address(this));
            if(quoteAsset!=address(0))IERC20(quoteAsset).forceApprove(pool,0);
            amount=q.used;
        } else {
            address[] memory path=new address[](2);
            path[0]=quoteAsset==address(0)?IV2Router(router).WETH():quoteAsset;path[1]=token;
            if(quoteAsset==address(0))IQuoteSwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value:amount}(minTokens,path,address(this),deadline);
            else {
                IERC20(quoteAsset).forceApprove(router,amount);
                IQuoteSwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount,minTokens,path,address(this),deadline);
                IERC20(quoteAsset).forceApprove(router,0);
            }
        }
        uint256 received=IERC20(token).balanceOf(address(this))-before_;
        if(received<minTokens)revert InvalidAmount();
        ILaunchTokenV3(token).burn(received);totalBuybackBurned+=received;emit BuybackExecuted(amount,received);
    }
    /// @notice Allocate already collected tax budgets to the immutable primary pair; all minted LP is burned.
    function addLiquidity(uint256 maxQuote,uint256 maxTokens,uint256 minLp) external nonReentrant {
        if(msg.sender!=creator||pair==address(0)||minLp==0)revert Unauthorized();
        _addLiquidity(maxQuote,maxTokens,minLp);
    }
    function _addLiquidity(uint256 maxQuote,uint256 maxTokens,uint256 minLp) private {
        (uint112 r0,uint112 r1,)=IV2Pair(pair).getReserves();
        (uint256 rq,uint256 rt)=IV2Pair(pair).token0()==token?(uint256(r1),uint256(r0)):(uint256(r0),uint256(r1));
        if(rq==0||rt==0)revert InvalidAmount();
        uint256 q=Math.min(maxQuote,liquidityBudget[quoteAsset]);
        uint256 t=Math.mulDiv(q,rt,rq);
        uint256 available=Math.min(maxTokens,liquidityBudget[token]);
        if(t>available){t=available;q=Math.mulDiv(t,rq,rt);}
        if(q==0||t==0)revert InvalidAmount();
        liquidityBudget[quoteAsset]-=q;liquidityBudget[token]-=t;
        IERC20(token).safeTransfer(pair,t);
        if(quoteAsset==address(0)){
            address wrapped=IV2Router(router).WETH();IWBNB(wrapped).deposit{value:q}();IERC20(wrapped).safeTransfer(pair,q);
        }else IERC20(quoteAsset).safeTransfer(pair,q);
        uint256 lp=IV2Pair(pair).mint(address(0xdead));if(lp<minLp)revert InvalidAmount();
        emit LiquidityAdded(q,t,lp);
    }

    /// @notice Permissionless, parameter-free maintenance. A funded server keeper calls this automatically.
    /// Callers cannot select recipients, routes, prices or spend holder/creator credits.
    /// DEX processing uses a 3-minute cumulative-price observation, a 1% spot deviation limit,
    /// bounded batches and router minimum output. Failed executions leave all budgets untouched.
    function runAutomation() external nonReentrant returns(uint256 actions) {
        uint256 minimum=MultiAssetCurve(pool).virtualQuote()/10_000;
        if(pair==address(0)) {
            if(burnBudget<minimum||block.timestamp<lastAutomationAt+30)return 0;
            MultiAssetCurve.BuyQuote memory q=MultiAssetCurve(pool).quoteBuy(burnBudget);
            if(q.tokens==0)return 0;
            lastAutomationAt=block.timestamp;
            _executeBuyback(burnBudget,q.tokens,block.timestamp);
            emit AutomationRun(1);return 1;
        }
        (uint256 rq,uint256 rt)=_reserves();
        if(rq==0||rt==0)return 0;
        bool pending=burnBudget>=minimum||liquidityBudget[quoteAsset]>=minimum
            ||liquidityBudget[token]>=Math.mulDiv(minimum,rt,rq);
        if(!pending)return 0;
        uint256 cumulative=_cumulative(rq,rt);
        uint256 elapsed=block.timestamp-observationAt;
        if(observationAt==0||elapsed>1800){_observe(cumulative);return 4;}
        if(elapsed<OBSERVATION_WINDOW)return 0;
        uint256 delta;unchecked {delta=cumulative-priceCumulative;}
        uint256 average=delta/elapsed;
        uint256 spot=Math.mulDiv(rt,2**112,rq);
        _observe(cumulative);
        // Refresh the observation after drift; never chase a manipulated spot within this call.
        if(average==0||Math.mulDiv(spot>average?spot-average:average-spot,10_000,average)>100)return 4;
        uint256 amount=Math.min(burnBudget,rq/400);
        if(amount>=minimum){
            uint256 out=_minimumOutput(amount,rq,rt);
            _executeBuyback(amount,out,block.timestamp);actions|=1;
        }
        // Process independent one-sided LP budgets. Selling half of excess project tokens or
        // buying tokens with half of excess quote makes LP possible after either kind of trade.
        (rq,rt)=_reserves();
        uint256 qBudget=Math.min(liquidityBudget[quoteAsset],rq/200);
        uint256 tBudget=Math.min(liquidityBudget[token],rt/200);
        uint256 tokenValue=Math.mulDiv(tBudget,rq,rt);
        if(qBudget>=minimum||tokenValue>=minimum){
            if(qBudget>tokenValue+minimum){
                uint256 input=(qBudget-tokenValue)/2;
                liquidityBudget[quoteAsset]-=input;
                uint256 received=_swapQuote(input,_minimumOutput(input,rq,rt));
                liquidityBudget[token]+=received;
            }else if(tokenValue>qBudget+minimum){
                uint256 input=Math.mulDiv((tokenValue-qBudget)/2,rt,rq);
                liquidityBudget[token]-=input;
                uint256 received=_swapToken(input,_minimumOutput(input,rt,rq));
                liquidityBudget[quoteAsset]+=received;
            }
            (rq,rt)=_reserves();
            uint256 q=Math.min(liquidityBudget[quoteAsset],rq/100);
            uint256 t=Math.min(liquidityBudget[token],rt/100);
            uint256 expected=Math.min(Math.mulDiv(q,IV2Pair(pair).totalSupply(),rq),Math.mulDiv(t,IV2Pair(pair).totalSupply(),rt));
            if(expected>100){_addLiquidity(q,t,expected*99/100);actions|=2;}
        }
        lastAutomationAt=block.timestamp;
        emit AutomationRun(actions|4);
        return actions|4;
    }
    function _reserves() private view returns(uint256 rq,uint256 rt){
        (uint112 r0,uint112 r1,)=IV2Pair(pair).getReserves();
        return IV2Pair(pair).token0()==token?(uint256(r1),uint256(r0)):(uint256(r0),uint256(r1));
    }
    function _cumulative(uint256 rq,uint256 rt) private view returns(uint256 result){
        bool quoteFirst=IV2Pair(pair).token0()!=token;
        result=quoteFirst?ICumulativePair(pair).price0CumulativeLast():ICumulativePair(pair).price1CumulativeLast();
        (,,uint32 previous)=IV2Pair(pair).getReserves();
        unchecked {result+=Math.mulDiv(rt,2**112,rq)*(uint32(block.timestamp)-previous);}
    }
    function _observe(uint256 cumulative) private {
        priceCumulative=cumulative;observationAt=block.timestamp;emit PriceObserved(block.timestamp);
    }
    function _minimumOutput(uint256 amount,uint256 inputReserve,uint256 outputReserve) private pure returns(uint256){
        uint256 expected=Math.mulDiv(amount*9975,outputReserve,inputReserve*10_000+amount*9975);
        uint256 minimum=expected*99/100;if(minimum==0)revert InvalidAmount();return minimum;
    }
    function _swapQuote(uint256 amount,uint256 minimum) private returns(uint256 received){
        uint256 before_=IERC20(token).balanceOf(address(this));
        address[] memory path=new address[](2);path[0]=quoteAsset==address(0)?IV2Router(router).WETH():quoteAsset;path[1]=token;
        if(quoteAsset==address(0))IQuoteSwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value:amount}(minimum,path,address(this),block.timestamp);
        else {
            IERC20(quoteAsset).forceApprove(router,amount);
            IQuoteSwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount,minimum,path,address(this),block.timestamp);
            IERC20(quoteAsset).forceApprove(router,0);
        }
        received=IERC20(token).balanceOf(address(this))-before_;
        if(received<minimum)revert InvalidAmount();
    }
    function _swapToken(uint256 amount,uint256 minimum) private returns(uint256 received){
        address settled=quoteAsset==address(0)?IV2Router(router).WETH():quoteAsset;
        uint256 before_=IERC20(settled).balanceOf(address(this));
        address[] memory path=new address[](2);path[0]=token;path[1]=settled;
        IERC20(token).forceApprove(router,amount);
        IQuoteSwapRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount,minimum,path,address(this),block.timestamp);
        IERC20(token).forceApprove(router,0);
        received=IERC20(settled).balanceOf(address(this))-before_;
        if(received<minimum)revert InvalidAmount();
        if(quoteAsset==address(0))IUnwrap(settled).withdraw(received);
    }
    function _send(address asset,address to,uint256 amount) private {
        if(asset==address(0)){(bool ok,)=to.call{value:amount}("");if(!ok)revert TransferFailed();}
        else IERC20(asset).safeTransfer(to,amount);
    }
    receive() external payable {if(msg.sender!=pool&&msg.sender!=IV2Router(router).WETH())revert Unauthorized();}
}
