// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IWBNB} from "../internal/Interfaces.sol";
import {BNBQuoteAdapter,IPancakeV3Input,IPancakeV2Input} from "./BNBQuoteAdapter.sol";
import {MultiAssetCurve} from "../internal/MultiAssetCurve.sol";

interface ITradingFactory {
    function projects(address) external view returns(address creator,address pool,address vault,uint64 createdAt);
    function projectVersion(address) external view returns(uint8);
}
interface IWithdrawBNB {function withdraw(uint256 amount) external;}

/// @notice Exact-input BNB trades using factory-registered projects and immutable Pancake routers.
/// User tokens go directly into a curve on sell; no tax exemption or transfer bypass is introduced.
contract BNBTradeRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;
    ITradingFactory public immutable factory;
    BNBQuoteAdapter public immutable adapter;
    address public immutable wrappedBNB;
    address public immutable v2Router;
    address public immutable v3Router;
    error InvalidTrade();error Slippage();error TransferFailed();error LegacyCurve();
    event RoutedTrade(address indexed trader,address indexed token,bool isBuy,uint256 bnbAmount,uint256 tokenAmount);
    event QuoteRefunded(address indexed trader,address indexed asset,uint256 amount);
    constructor(address factory_,address adapter_){
        if(factory_.code.length==0||adapter_.code.length==0)revert InvalidTrade();
        factory=ITradingFactory(factory_);adapter=BNBQuoteAdapter(adapter_);
        wrappedBNB=adapter.wrappedBNB();v2Router=adapter.v2Router();v3Router=adapter.v3Router();
    }
    receive() external payable {if(msg.sender!=wrappedBNB)revert InvalidTrade();}
    function _project(address token) private view returns(MultiAssetCurve pool,address quote){
        (,address p,,)=factory.projects(token);
        if(p==address(0)||factory.projectVersion(token)!=3)revert InvalidTrade();
        pool=MultiAssetCurve(p);quote=pool.quoteAsset();
        if(pool.token()!=token||pool.router()!=v2Router||quote==address(0))revert InvalidTrade();
    }
    function buyWithBNB(address token,uint256 minQuote,uint256 minTokens,uint256 deadline,BNBQuoteAdapter.Route calldata route)
        external payable nonReentrant returns(uint256 bought){
        if(msg.value==0||minQuote==0||minTokens==0||block.timestamp>deadline)revert InvalidTrade();
        (MultiAssetCurve pool,address quote)=_project(token);
        uint256 beforeQuote=IERC20(quote).balanceOf(address(this));
        uint256 beforeWrapped=IERC20(wrappedBNB).balanceOf(address(this));
        uint256 beforeTokens=IERC20(token).balanceOf(msg.sender);
        uint256 received=adapter.convertBNB{value:msg.value}(quote,minQuote,deadline,address(this),route);
        if(!pool.graduated()){
            IERC20(quote).forceApprove(address(pool),received);
            pool.buy(received,minTokens,deadline,msg.sender);
            IERC20(quote).forceApprove(address(pool),0);
        }else{
            address[] memory path=new address[](2);path[0]=quote;path[1]=token;
            IERC20(quote).forceApprove(v2Router,received);
            IPancakeV2Input(v2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(received,minTokens,path,msg.sender,deadline);
            IERC20(quote).forceApprove(v2Router,0);
        }
        bought=IERC20(token).balanceOf(msg.sender)-beforeTokens;
        if(bought<minTokens)revert Slippage();
        uint256 refund=IERC20(quote).balanceOf(address(this))-beforeQuote;
        if(refund!=0){IERC20(quote).safeTransfer(msg.sender,refund);emit QuoteRefunded(msg.sender,quote,refund);}
        if(quote!=wrappedBNB){uint256 unspent=IERC20(wrappedBNB).balanceOf(address(this))-beforeWrapped;if(unspent!=0)_payBNB(msg.sender,unspent);}
        emit RoutedTrade(msg.sender,token,true,msg.value,bought);
    }
    function sellToBNB(address token,uint256 amount,uint256 minQuote,uint256 minBNB,uint256 deadline,BNBQuoteAdapter.Route calldata route)
        external nonReentrant returns(uint256 output){
        if(amount==0||minQuote==0||minBNB==0||block.timestamp>deadline)revert InvalidTrade();
        (MultiAssetCurve pool,address quote)=_project(token);
        uint256 beforeQuote=IERC20(quote).balanceOf(address(this));
        if(!pool.graduated()){
            try pool.tradeRouter() returns(address router_){if(router_!=address(this))revert LegacyCurve();}catch{revert LegacyCurve();}
            pool.sellFor(msg.sender,amount,minQuote,deadline,address(this));
        }else{
            uint256 beforeToken=IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(msg.sender,address(this),amount);
            uint256 received=IERC20(token).balanceOf(address(this))-beforeToken;
            address[] memory path=new address[](2);path[0]=token;path[1]=quote;
            IERC20(token).forceApprove(v2Router,received);
            IPancakeV2Input(v2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(received,minQuote,path,address(this),deadline);
            IERC20(token).forceApprove(v2Router,0);
        }
        uint256 proceeds=IERC20(quote).balanceOf(address(this))-beforeQuote;
        if(proceeds<minQuote)revert Slippage();
        output=_convert(quote,proceeds,minBNB,deadline,route);
        _payBNB(msg.sender,output);
        emit RoutedTrade(msg.sender,token,false,output,amount);
    }
    /// @notice Completes BNB conversion for immutable, older pools that require the holder to call sell directly.
    function convertQuoteToBNB(address asset,uint256 amount,uint256 minBNB,uint256 deadline,BNBQuoteAdapter.Route calldata route)
        external nonReentrant returns(uint256 output){
        if(asset==address(0)||amount==0||minBNB==0||block.timestamp>deadline)revert InvalidTrade();
        uint256 before_=IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender,address(this),amount);
        if(IERC20(asset).balanceOf(address(this))-before_!=amount)revert InvalidTrade();
        output=_convert(asset,amount,minBNB,deadline,route);_payBNB(msg.sender,output);
    }
    function _convert(address asset,uint256 amount,uint256 minimum,uint256 deadline,BNBQuoteAdapter.Route calldata route) private returns(uint256 output){
        if(asset==wrappedBNB){if(amount<minimum)revert Slippage();return amount;}
        uint256 before_=IERC20(wrappedBNB).balanceOf(address(this));
        uint256 assetBefore=IERC20(asset).balanceOf(address(this));
        address router_;
        if(route.kind==1){
            if(route.v2Path.length<2||route.v2Path.length>4||route.v2Path[0]!=asset||route.v2Path[route.v2Path.length-1]!=wrappedBNB)revert InvalidTrade();
            router_=v2Router;IERC20(asset).forceApprove(router_,amount);
            IPancakeV2Input(router_).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount,minimum,route.v2Path,address(this),deadline);
        }else if(route.kind==2){
            bytes calldata path=route.v3Path;
            if(path.length<43||path.length>89||(path.length-20)%23!=0||address(bytes20(path[:20]))!=asset||address(bytes20(path[path.length-20:]))!=wrappedBNB)revert InvalidTrade();
            router_=v3Router;IERC20(asset).forceApprove(router_,amount);
            IPancakeV3Input(router_).exactInput(IPancakeV3Input.ExactInputParams(path,address(this),deadline,amount,minimum));
        }else revert InvalidTrade();
        IERC20(asset).forceApprove(router_,0);
        output=IERC20(wrappedBNB).balanceOf(address(this))-before_;
        if(output<minimum)revert Slippage();
        uint256 unused=IERC20(asset).balanceOf(address(this))-(assetBefore-amount);
        if(unused!=0){IERC20(asset).safeTransfer(msg.sender,unused);emit QuoteRefunded(msg.sender,asset,unused);}
    }
    function _payBNB(address recipient,uint256 amount) private {
        IWithdrawBNB(wrappedBNB).withdraw(amount);
        (bool ok,)=recipient.call{value:amount}("");if(!ok)revert TransferFailed();
    }
}
