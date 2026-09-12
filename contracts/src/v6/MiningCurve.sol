// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LaunchMining, LaunchMiningDeployer} from "./LaunchMining.sol";
import {MiningRevenueVault} from "./MiningRevenueVault.sol";
import {QuoteAssetRegistry} from "../QuoteAssetRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IV2Factory, IV2Router, IV2Pair, IWBNB} from "../Interfaces.sol";
import {ILaunchTokenV3, IRevenueVaultV3} from "../v3/LaunchTypes.sol";

/// @notice Quotes, collateral, taxes and graduation all use the same immutable asset.
/// Preserves the original initial virtual reserves, with an independent early graduation target.
interface IMiningFactoryConfig { function quoteRegistry() external view returns(address); }
interface IPairCodeHash { function INIT_CODE_PAIR_HASH() external view returns(bytes32); }
contract MiningCurve is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant VERSION = 6;
    uint256 public constant PLATFORM_BPS = 100;
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    uint256 public constant INITIAL_VIRTUAL_TOKENS = (uint256(800_000_000 ether) * 98 + 72) / 73;
    uint256 public saleTarget;
    address public immutable miningDeployer;
    address public stakingPool;
    address public pricingRegistry;
    uint256 public miningBudget;
    uint256 public miningReleased;
    uint256 public constant SEEDING_FEE_BPS = 200;
    uint256 public virtualTokenOffset;
    address private immutable launchFactory;
    address public token;
    address public vault;
    address public treasury;
    address public router;
    address public quoteAsset;
    address public pair;
    uint8 public quoteDecimals;
    uint256 public virtualQuote;
    uint256 public graduationTarget;
    uint256 public reserveQuote;
    uint256 public reserveTokens;
    uint256 public platformCredit;
    uint256 public volumeQuote;
    uint256 public tradeCount;
    bool public graduated;
    bool internal initialized;
    address private initializerFactory;
    address public tradeRouter;

    struct Init {
        address token; address vault; address treasury; address router; address quoteAsset;
        uint8 quoteDecimals; uint256 virtualQuote; uint256 graduationTarget;
    }
    struct BuyQuote {
        uint256 tokens; uint256 used; uint256 refund; uint256 platformFee; uint256 tax; uint256 net;
    }
    error InvalidConfig(); error InvalidAmount(); error Slippage(); error Deadline();
    error Graduated(); error NotReady(); error TransferFailed(); error UnsupportedQuoteTransfer();
    event TradeV3(address indexed trader, bool indexed isBuy, uint256 quoteAmount, uint256 tokenAmount,
        uint256 price, uint256 reserveQuote, uint256 platformFee, uint256 tax);
    event GraduationV3(address indexed token, address indexed pair, address quoteAsset, uint256 quoteAmount,
        uint256 tokenAmount, uint256 lp, uint256 surplusBurned);
    event PlatformClaimed(uint256 amount);

    constructor(address factory_, address miningDeployer_) {
        if(factory_.code.length==0)revert InvalidConfig();
        launchFactory=factory_;
        if(miningDeployer_.code.length==0)revert InvalidConfig();
        miningDeployer=miningDeployer_;
    }
    function initialize(Init calldata p) public virtual {
        if (msg.sender!=launchFactory || initialized || p.token.code.length == 0 || p.vault.code.length == 0 || p.treasury == address(0)
            || p.router.code.length == 0 || p.virtualQuote < 1e6 || p.graduationTarget == 0
            || p.graduationTarget > type(uint112).max || p.quoteDecimals < 6 || p.quoteDecimals > 18
            || (p.quoteAsset != address(0) && p.quoteAsset.code.length == 0)) revert InvalidConfig();
        initialized = true; initializerFactory=msg.sender;
        token=p.token; vault=p.vault; treasury=p.treasury; router=p.router;
        quoteAsset=p.quoteAsset; quoteDecimals=p.quoteDecimals;
        virtualQuote=p.virtualQuote; graduationTarget=p.graduationTarget; reserveTokens=INITIAL_SUPPLY;
        virtualTokenOffset=INITIAL_VIRTUAL_TOKENS-INITIAL_SUPPLY;
        saleTarget=Math.mulDiv(INITIAL_VIRTUAL_TOKENS,p.graduationTarget,p.virtualQuote+p.graduationTarget);
        if(saleTarget==0||saleTarget>=INITIAL_SUPPLY)revert InvalidConfig();
        pricingRegistry=IMiningFactoryConfig(launchFactory).quoteRegistry();
        stakingPool=LaunchMiningDeployer(miningDeployer).deploy(p.token,p.vault);
        MiningRevenueVault(payable(p.vault)).setStakingPool(stakingPool);
        address settled=p.quoteAsset==address(0)?IV2Router(p.router).WETH():p.quoteAsset;
        address factory=IV2Router(p.router).factory();
        (address a,address b)=p.token<settled?(p.token,settled):(settled,p.token);
        bytes32 codeHash=IPairCodeHash(factory).INIT_CODE_PAIR_HASH();
        if(codeHash==bytes32(0))revert InvalidConfig();
        address futurePair=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),factory,keccak256(abi.encodePacked(a,b)),codeHash)))));
        address existing=IV2Factory(factory).getPair(p.token,settled);
        if(existing!=address(0)&&existing!=futurePair)revert InvalidConfig();
        // Reserve the canonical destination now; deploying the pair belongs to graduation.
        ILaunchTokenV3(p.token).reservePair(futurePair);
    }
    /// @notice Fixed at creation. A router can sell only with the seller's allowance to this pool.
    function setTradeRouter(address router_) external {
        if(msg.sender!=initializerFactory||tradeRouter!=address(0)||router_.code.length==0)revert InvalidConfig();
        tradeRouter=router_;
    }
    function spotPrice() external view returns (uint256) {
        // 1e18 quote tokens per whole launch token, independent of the quote token's decimals.
        return Math.mulDiv(virtualQuote + reserveQuote, 1e36, reserveTokens+virtualTokenOffset) / 10 ** quoteDecimals;
    }
    function progressBps() external view returns (uint256) { return Math.min(10_000,(INITIAL_SUPPLY-reserveTokens)*10_000/saleTarget); }
    function quoteBuy(uint256 amount) public view returns (BuyQuote memory q) {
        q.refund=amount;
        if (graduated || reserveQuote >= graduationTarget || amount == 0) return q;
        uint256 taxBps=ILaunchTokenV3(token).buyTaxBps();
        uint256 remaining=graduationTarget-reserveQuote;
        uint256 maxGross=Math.mulDiv(remaining, 10_000, 10_000-PLATFORM_BPS-taxBps, Math.Rounding.Ceil);
        q.used=Math.min(amount,maxGross);
        q.platformFee=q.used*PLATFORM_BPS/10_000;
        q.tax=q.used*taxBps/10_000;
        q.net=q.used-q.platformFee-q.tax;
        // Refund sub-unit rounding excess rather than introducing a tax on a tax-free launch.
        if(q.net>remaining) { q.used-=q.net-remaining; q.net=remaining; }
        q.tokens=q.net==remaining?reserveTokens-(INITIAL_SUPPLY-saleTarget):
            Math.min(reserveTokens-(INITIAL_SUPPLY-saleTarget),Math.mulDiv(reserveTokens+virtualTokenOffset,q.net,virtualQuote+reserveQuote+q.net));
        q.refund=amount-q.used;
    }
    function buy(uint256 amount, uint256 minTokens, uint256 deadline, address recipient) external payable nonReentrant {
        if(block.timestamp>deadline) revert Deadline();
        if(graduated || reserveQuote>=graduationTarget) revert Graduated();
        if(recipient==address(0) || recipient==address(this) || recipient==token) revert InvalidConfig();
        BuyQuote memory q=quoteBuy(amount);
        if(q.tokens==0) revert InvalidAmount();
        if(q.tokens<minTokens) revert Slippage();
        if(quoteAsset==address(0)) {
            if(msg.value!=amount) revert InvalidAmount();
        } else {
            if(msg.value!=0) revert InvalidAmount();
            uint256 before_=IERC20(quoteAsset).balanceOf(address(this));
            // ERC-20 excess is never taken from the wallet.
            IERC20(quoteAsset).safeTransferFrom(msg.sender,address(this),q.used);
            if(IERC20(quoteAsset).balanceOf(address(this))-before_!=q.used) revert UnsupportedQuoteTransfer();
        }
        reserveTokens-=q.tokens; reserveQuote+=q.net;
        platformCredit+=q.platformFee; volumeQuote+=q.used; tradeCount++;
        IERC20(token).safeTransfer(recipient,q.tokens);
        _notify(q.tax);
        if(quoteAsset==address(0) && q.refund!=0) _send(msg.sender,q.refund);
        emit TradeV3(recipient,true,q.used,q.tokens,Math.mulDiv(q.net,1e36,q.tokens)/10**quoteDecimals,
            reserveQuote,q.platformFee,q.tax);
    }
    function quoteSell(uint256 amount) public view returns(uint256 output,uint256 platformFee,uint256 tax) {
        if(graduated || amount==0) return(0,0,0);
        uint256 gross=Math.mulDiv(virtualQuote+reserveQuote,amount,reserveTokens+virtualTokenOffset+amount);
        if(gross>reserveQuote) return(0,0,0);
        platformFee=gross*PLATFORM_BPS/10_000;
        tax=gross*ILaunchTokenV3(token).sellTaxBps()/10_000;
        output=gross-platformFee-tax;
    }
    function sell(uint256 amount,uint256 minimum,uint256 deadline,address recipient) external nonReentrant {
        _sell(msg.sender,amount,minimum,deadline,recipient);
    }
    function sellFor(address seller,uint256 amount,uint256 minimum,uint256 deadline,address recipient) external nonReentrant {
        if(msg.sender!=tradeRouter||tradeRouter==address(0))revert InvalidConfig();
        _sell(seller,amount,minimum,deadline,recipient);
    }
    function _sell(address seller,uint256 amount,uint256 minimum,uint256 deadline,address recipient) private {
        if(block.timestamp>deadline) revert Deadline();
        if(graduated) revert Graduated();
        if(recipient==address(0) || recipient==address(this)) revert InvalidConfig();
        (uint256 output,uint256 fee,uint256 tax)=quoteSell(amount);
        if(output==0) revert InvalidAmount();
        if(output<minimum) revert Slippage();
        IERC20(token).safeTransferFrom(seller,address(this),amount);
        reserveTokens+=amount; reserveQuote-=output+fee+tax;
        platformCredit+=fee; volumeQuote+=output+fee+tax; tradeCount++;
        _notify(tax); _send(recipient,output);
        emit TradeV3(seller,false,output,amount,Math.mulDiv(output+fee+tax,1e36,amount)/10**quoteDecimals,
            reserveQuote,fee,tax);
    }
    /// @notice Anyone can graduate. Quote-oracle outages cannot prevent migration or sellback.
    function graduate() external nonReentrant {
        if(graduated) revert Graduated();
        if(reserveQuote<graduationTarget) revert NotReady();
        address settled=quoteAsset==address(0)?IV2Router(router).WETH():quoteAsset;
        address factory=IV2Router(router).factory();
        address p=IV2Factory(factory).getPair(token,settled);
        if(p==address(0)) p=IV2Factory(factory).createPair(token,settled);
        if(IV2Pair(p).totalSupply()!=0) revert InvalidConfig();
        uint256 seedingFee=reserveQuote*SEEDING_FEE_BPS/10_000;
        uint256 quote=reserveQuote-seedingFee;
        platformCredit+=seedingFee;
        // Identical spot price on both sides of graduation; phantom reserves never become real liquidity.
        uint256 seed=Math.mulDiv(quote,reserveTokens+virtualTokenOffset,virtualQuote+reserveQuote);
        uint256 surplus=IERC20(token).balanceOf(address(this))-seed;
        graduated=true; pair=p;
        miningBudget=surplus;
        ILaunchTokenV3(token).activatePair(p);
        IERC20(token).safeTransfer(p,seed);
        if(quoteAsset==address(0)) IWBNB(settled).deposit{value:quote}();
        IERC20(settled).safeTransfer(p,quote);
        uint256 lp=IV2Pair(p).mint(address(0xdead));
        LaunchMining(stakingPool).activate(surplus);
        emit GraduationV3(token,p,quoteAsset,quote,seed,lp,0);
        emit MiningFunded(stakingPool,surplus);
    }
    event MiningFunded(address indexed stakingPool,uint256 rewards);
    function releaseMiningReward(address recipient,uint256 amount) external nonReentrant {
        if(msg.sender!=stakingPool||!graduated||recipient==address(0)||amount>miningBudget-miningReleased)revert InvalidConfig();
        miningReleased+=amount;IERC20(token).safeTransfer(recipient,amount);
    }
    /// @notice Snapshot for cost-based UI statistics; this price never determines mining payouts.
    function stakingPriceUSD() external view returns(uint256) {
        if(!graduated)return 0;
        (uint112 r0,uint112 r1,)=IV2Pair(pair).getReserves();
        bool first=IV2Pair(pair).token0()==token;
        uint256 tokenReserve=first?r0:r1;
        uint256 quoteReserve=first?r1:r0;
        if(tokenReserve==0)return 0;
        (uint256 usd,)=QuoteAssetRegistry(pricingRegistry).priceUsd(quoteAsset);
        // Normalize before division: six-decimal quotes must not round tiny token prices to zero.
        uint256 normalized = quoteDecimals <= 18 ? quoteReserve * 10**(18-quoteDecimals) : quoteReserve / 10**(quoteDecimals-18);
        return Math.mulDiv(normalized,usd,tokenReserve);
    }
    function claimPlatform() external nonReentrant {
        uint256 amount=platformCredit;
        if(amount==0) revert InvalidAmount();
        platformCredit=0; _send(treasury,amount); emit PlatformClaimed(amount);
    }
    function _notify(uint256 amount) private {
        if(amount==0)return;
        if(quoteAsset==address(0)) IRevenueVaultV3(vault).notifyQuote{value:amount}(amount);
        else {
            IERC20(quoteAsset).forceApprove(vault,amount);
            IRevenueVaultV3(vault).notifyQuote(amount);
            IERC20(quoteAsset).forceApprove(vault,0);
        }
    }
    function _send(address to,uint256 amount) private {
        if(quoteAsset==address(0)) {
            (bool ok,)=to.call{value:amount}(""); if(!ok)revert TransferFailed();
        } else IERC20(quoteAsset).safeTransfer(to,amount);
    }
}
