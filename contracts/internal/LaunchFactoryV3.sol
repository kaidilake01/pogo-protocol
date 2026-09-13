// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {LaunchFactory} from "./LaunchFactory.sol";
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {LaunchTypes} from "./LaunchTypes.sol";
import {LaunchTokenV3} from "./LaunchTokenV3.sol";
import {MultiAssetCurve} from "./MultiAssetCurve.sol";
import {RevenueVault} from "./RevenueVault.sol";
import {BNBQuoteAdapter} from "../src/BNBQuoteAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Appends storage and adds a new creation ABI. V2 project records, methods and clone templates remain intact.
contract LaunchFactoryV3 is LaunchFactory {
    using SafeERC20 for IERC20;
    uint256 public constant MULTI_ASSET_VERSION=3;
    QuoteAssetRegistry public quoteRegistry;
    address public tokenImplementationV3;
    address public vaultImplementationV3;
    address public poolImplementationV3;
    uint32 public templateVersionV3;
    mapping(address=>uint8) public projectVersion;
    BNBQuoteAdapter public bnbAdapter;
    address private refundPool;
    address public tradeRouterV3;
    struct CreateParamsV3 {
        string name;string symbol;string metadataURI;bytes32 salt;
        address quoteAsset;bytes32 expectedConfig;uint256 minTarget;uint256 maxTarget;
        LaunchTypes.Tax tax;
    }
    struct DeveloperBuy {
        uint256 amount;uint256 minQuote;uint256 minTokens;uint256 deadline;bool payWithBNB;
        BNBQuoteAdapter.Route route;
    }
    event TemplatesV3Updated(uint32 version,address registry,address token,address vault,address pool);
    event BNBAdapterUpdated(address adapter);
    event TradeRouterUpdated(address router);
    event DeveloperBought(address indexed token,address indexed developer,uint256 inputAmount,bool paidBNB,uint256 tokens);
    event TokenCreatedV3(address indexed token,address indexed creator,address indexed quoteAsset,
        address pool,address vault,string name,string symbol,string metadataURI,LaunchTypes.Tax tax,
        uint256 target,uint256 virtualQuote,uint256 assetUsd,uint256 bnbUsd,uint8 quoteDecimals);

    function setTemplatesV3(address registry_,address token_,address vault_,address pool_) external onlyOwner {
        if(registry_.code.length==0||token_.code.length==0||vault_.code.length==0||pool_.code.length==0)revert InvalidConfig();
        quoteRegistry=QuoteAssetRegistry(registry_);tokenImplementationV3=token_;
        vaultImplementationV3=vault_;poolImplementationV3=pool_;templateVersionV3++;
        emit TemplatesV3Updated(templateVersionV3,registry_,token_,vault_,pool_);
    }
    function launchConfigHash(address quote) public view virtual returns(bytes32){
        return keccak256(abi.encode(quoteRegistry.configHash(quote),tokenImplementationV3,vaultImplementationV3,
            poolImplementationV3,treasury,router,CREATION_FEE(),templateVersionV3,address(bnbAdapter),tradeRouterV3));
    }
    function predictTokenV3(address creator,bytes32 salt) public view virtual returns(address){
        return Clones.predictDeterministicAddress(tokenImplementationV3,effectiveSalt(creator,salt),address(this));
    }
    function createTokenV3(CreateParamsV3 calldata p) public payable nonReentrant returns(address token){
        if(msg.value!=CREATION_FEE())revert InvalidConfig();
        return _createTokenV3(p);
    }
    function setBNBAdapter(address adapter) external onlyOwner {
        if(adapter.code.length==0)revert InvalidConfig();bnbAdapter=BNBQuoteAdapter(adapter);emit BNBAdapterUpdated(adapter);
    }
    function setTradeRouterV3(address router_) external onlyOwner {
        if(router_.code.length==0)revert InvalidConfig();
        tradeRouterV3=router_;emit TradeRouterUpdated(router_);
    }
    function setTradingTemplate(address pool_,address router_) external onlyOwner {
        if(pool_.code.length==0||router_.code.length==0)revert InvalidConfig();
        poolImplementationV3=pool_;tradeRouterV3=router_;templateVersionV3++;
        emit TemplatesV3Updated(templateVersionV3,address(quoteRegistry),tokenImplementationV3,vaultImplementationV3,pool_);
        emit TradeRouterUpdated(router_);
    }
    /// @notice One transaction: deploy, optionally convert BNB to the quote asset, and buy for the creator.
    /// No tx.origin, forwarded creator identity, intermediate wallet transfer or second signing step.
    function createTokenAndBuyV3(CreateParamsV3 calldata p,DeveloperBuy calldata b)
        public payable nonReentrant returns(address token){
        bool nativeInput=b.payWithBNB||p.quoteAsset==address(0);
        if(b.amount==0||b.minTokens==0||block.timestamp>b.deadline||msg.value!=CREATION_FEE()+(nativeInput?b.amount:0))revert InvalidConfig();
        uint256 nativeBefore=address(this).balance-msg.value;
        uint256 quoteBefore=p.quoteAsset==address(0)?0:IERC20(p.quoteAsset).balanceOf(address(this));
        token=_createTokenV3(p);
        address pool=projects[token].pool;
        uint256 spend=b.amount;
        if(p.quoteAsset!=address(0)){
            if(b.payWithBNB){
                if(address(bnbAdapter)==address(0)||b.minQuote==0)revert InvalidConfig();
                address wrapped=bnbAdapter.wrappedBNB();
                uint256 wrappedBefore=IERC20(wrapped).balanceOf(address(this));
                spend=bnbAdapter.convertBNB{value:b.amount}(p.quoteAsset,b.minQuote,b.deadline,address(this),b.route);
                if(wrapped!=p.quoteAsset){
                    uint256 unused=IERC20(wrapped).balanceOf(address(this))-wrappedBefore;
                    if(unused!=0)IERC20(wrapped).safeTransfer(msg.sender,unused);
                }
            }else{
                IERC20(p.quoteAsset).safeTransferFrom(msg.sender,address(this),spend);
                if(IERC20(p.quoteAsset).balanceOf(address(this))-quoteBefore!=spend)revert InvalidConfig();
            }
            IERC20(p.quoteAsset).forceApprove(pool,spend);
        }
        refundPool=pool;
        MultiAssetCurve(pool).buy{value:p.quoteAsset==address(0)?spend:0}(spend,b.minTokens,b.deadline,msg.sender);
        refundPool=address(0);
        if(p.quoteAsset!=address(0)){
            IERC20(p.quoteAsset).forceApprove(pool,0);
            uint256 excess=IERC20(p.quoteAsset).balanceOf(address(this))-quoteBefore;
            if(excess!=0)IERC20(p.quoteAsset).safeTransfer(msg.sender,excess);
        }
        uint256 nativeRefund=address(this).balance-nativeBefore-CREATION_FEE();
        if(nativeRefund!=0){(bool ok,)=msg.sender.call{value:nativeRefund}("");if(!ok)revert TransferFailed();}
        emit DeveloperBought(token,msg.sender,b.amount,nativeInput,IERC20(token).balanceOf(msg.sender));
    }
    function _createTokenV3(CreateParamsV3 calldata p) private returns(address token){
        if(creationPaused)revert CreationPaused();
        if(bytes(p.name).length==0||bytes(p.symbol).length==0
            ||bytes(p.metadataURI).length>256||!LaunchTypes.valid(p.tax)
            ||p.expectedConfig!=launchConfigHash(p.quoteAsset)||p.minTarget==0||p.maxTarget<p.minTarget)revert InvalidConfig();
        QuoteAssetRegistry.LaunchQuote memory q=quoteRegistry.quoteLaunch(p.quoteAsset);
        if(q.target<p.minTarget||q.target>p.maxTarget)revert InvalidConfig();
        if(uint160(predictTokenV3(msg.sender,p.salt))&0xffff!=0x6666)revert InvalidSuffix();
        token=_deployTokenV3(effectiveSalt(msg.sender,p.salt));
        address pool=_deployPoolV3();address vault=_deployVaultV3();
        (,,,uint8 dp,,,)=quoteRegistry.assets(p.quoteAsset);
        RevenueVault(payable(vault)).initialize(token,msg.sender,pool,p.quoteAsset,router,p.tax);
        LaunchTokenV3(token).initialize(LaunchTokenV3.Init(p.name,p.symbol,p.metadataURI,pool,vault,p.tax.buyBps,p.tax.sellBps));
        MultiAssetCurve(pool).initialize(MultiAssetCurve.Init(token,vault,treasury,router,p.quoteAsset,dp,q.virtualQuote,q.target));
        if(tradeRouterV3!=address(0))MultiAssetCurve(pool).setTradeRouter(tradeRouterV3);
        projects[token]=Project(msg.sender,pool,vault,uint64(block.timestamp));tokens.push(token);projectVersion[token]=3;
        creationCredits+=CREATION_FEE();
        emit TokenCreatedV3(token,msg.sender,p.quoteAsset,pool,vault,p.name,p.symbol,p.metadataURI,p.tax,q.target,q.virtualQuote,q.assetUsd,q.bnbUsd,dp);
    }
    function _deployTokenV3(bytes32 salt) internal virtual returns(address){return Clones.cloneDeterministic(tokenImplementationV3,salt);}
    function _deployPoolV3() internal virtual returns(address){return Clones.clone(poolImplementationV3);}
    function _deployVaultV3() internal virtual returns(address){return Clones.clone(vaultImplementationV3);}
    receive() external payable {if(msg.sender!=refundPool||refundPool==address(0))revert InvalidConfig();}
}
