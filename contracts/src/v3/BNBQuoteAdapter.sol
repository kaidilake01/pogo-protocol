// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IV2Router,IWBNB} from "../Interfaces.sol";

interface IPancakeV3Input {
    struct ExactInputParams {bytes path;address recipient;uint256 deadline;uint256 amountIn;uint256 amountOutMinimum;}
    function exactInput(ExactInputParams calldata params) external payable returns(uint256);
}
interface IPancakeV2Input {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[] calldata,address,uint256) external;
}

/// @notice Stateless, exact-input BNB conversion through immutable Pancake routers. Never accepts arbitrary call data.
contract BNBQuoteAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public immutable wrappedBNB;
    address public immutable v2Router;
    address public immutable v3Router;
    struct Route {uint8 kind;address[] v2Path;bytes v3Path;}
    error InvalidRoute();error Slippage();
    event Converted(address indexed payer,address indexed asset,address indexed recipient,uint256 bnbIn,uint256 output);
    constructor(address wrapped_,address v2_,address v3_){
        if(wrapped_.code.length==0||v2_.code.length==0||v3_.code.length==0||IV2Router(v2_).WETH()!=wrapped_)revert InvalidRoute();
        wrappedBNB=wrapped_;v2Router=v2_;v3Router=v3_;
    }
    function convertBNB(address asset,uint256 minOutput,uint256 deadline,address recipient,Route calldata route)
        external payable nonReentrant returns(uint256 output){
        if(msg.value==0||minOutput==0||asset==address(0)||recipient==address(0)||recipient==address(this)||block.timestamp>deadline)revert InvalidRoute();
        uint256 quoteBefore=IERC20(asset).balanceOf(address(this));
        uint256 wrappedBefore=IERC20(wrappedBNB).balanceOf(address(this));
        IWBNB(wrappedBNB).deposit{value:msg.value}();
        if(asset!=wrappedBNB){
            address router;
            if(route.kind==1){
                if(route.v2Path.length<2||route.v2Path.length>4||route.v2Path[0]!=wrappedBNB||route.v2Path[route.v2Path.length-1]!=asset)revert InvalidRoute();
                router=v2Router;
                IERC20(wrappedBNB).forceApprove(router,msg.value);
                IPancakeV2Input(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(msg.value,minOutput,route.v2Path,address(this),deadline);
            }else if(route.kind==2){
                bytes calldata path=route.v3Path;
                if(path.length<43||path.length>89||(path.length-20)%23!=0
                    ||address(bytes20(path[:20]))!=wrappedBNB||address(bytes20(path[path.length-20:]))!=asset)revert InvalidRoute();
                router=v3Router;
                IERC20(wrappedBNB).forceApprove(router,msg.value);
                IPancakeV3Input(router).exactInput(IPancakeV3Input.ExactInputParams(path,address(this),deadline,msg.value,minOutput));
            }else revert InvalidRoute();
            IERC20(wrappedBNB).forceApprove(router,0);
            uint256 unused=IERC20(wrappedBNB).balanceOf(address(this))-wrappedBefore;
            // A router that partially fills cannot strand unspent input; return it as wrapped BNB.
            if(unused!=0)IERC20(wrappedBNB).safeTransfer(recipient,unused);
        }
        output=IERC20(asset).balanceOf(address(this))-quoteBefore;
        if(output<minOutput)revert Slippage();
        uint256 recipientBefore=IERC20(asset).balanceOf(recipient);
        IERC20(asset).safeTransfer(recipient,output);
        if(IERC20(asset).balanceOf(recipient)-recipientBefore!=output)revert Slippage();
        emit Converted(msg.sender,asset,recipient,msg.value,output);
    }
}
