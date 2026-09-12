// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PancakeTickMath} from "../internal/PancakeTickMath.sol";

interface ITwapPool {
    function token0() external view returns(address);
    function token1() external view returns(address);
    function fee() external view returns(uint24);
    function liquidity() external view returns(uint128);
    function observe(uint32[] calldata) external view returns(int56[] memory,uint160[] memory);
    function observations(uint256) external view returns(uint32,int56,uint160,bool);
    function slot0() external view returns(uint160,int24,uint16,uint16,uint16,uint32,bool);
}
interface ITwapFactory { function getPool(address,address,uint24) external view returns(address); }
interface ITwapUsdFeed {
    function decimals() external view returns(uint8);
    function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80);
}

/// @notice A read-only launch-price adapter. It never receives tokens or controls existing curves.
/// @dev A local DEX TWAP is not a globally aggregated PEPE price. Thin/history-deficient pools fail closed.
contract PancakeTwapQuoteFeed {
    ITwapPool public immutable pool;
    ITwapUsdFeed public immutable bnbUsdFeed;
    address public immutable asset;
    address public immutable wrappedBNB;
    bool public immutable assetIsToken0;
    uint256 public immutable minimumVirtualBNB;
    uint32 public constant WINDOW = 30 minutes;
    uint32 public constant BNB_MAX_AGE = 300;
    int24 public constant MAX_TICK_DEVIATION = 500;
    error InvalidConfiguration();
    error UnavailablePrice();

    constructor(address pool_,address factory_,address asset_,address wrapped_,address feed_,uint256 minimumBNB_) {
        if(pool_.code.length==0||factory_.code.length==0||asset_==wrapped_||asset_.code.length==0
            ||wrapped_.code.length==0||feed_.code.length==0||minimumBNB_<100 ether) revert InvalidConfiguration();
        ITwapPool p=ITwapPool(pool_);
        address t0=p.token0();address t1=p.token1();
        if(!((t0==asset_&&t1==wrapped_)||(t1==asset_&&t0==wrapped_))
            ||ITwapFactory(factory_).getPool(asset_,wrapped_,p.fee())!=pool_
            ||IERC20Metadata(asset_).decimals()!=18||IERC20Metadata(wrapped_).decimals()!=18
            ||ITwapUsdFeed(feed_).decimals()!=8) revert InvalidConfiguration();
        pool=p;asset=asset_;wrappedBNB=wrapped_;bnbUsdFeed=ITwapUsdFeed(feed_);
        assetIsToken0=t0==asset_;minimumVirtualBNB=minimumBNB_;
    }
    function decimals() external pure returns(uint8) { return 18; }
    function description() external pure returns(string memory) { return "Token / USD - Pancake V3 30m TWAP"; }

    function latestRoundData() external view returns(uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound) {
        (uint80 round,int256 bnbPrice,,uint256 bnbAt,uint80 answered)=bnbUsdFeed.latestRoundData();
        if(round==0||answered<round||bnbPrice<=0||bnbPrice>1e16||bnbAt==0||bnbAt>block.timestamp||block.timestamp-bnbAt>BNB_MAX_AGE) revert UnavailablePrice();
        (,int24 spotTick,uint16 index,,,,)=pool.slot0();
        (uint32 poolAt,,,bool initialized)=pool.observations(index);
        if(!initialized||poolAt==0||poolAt>block.timestamp) revert UnavailablePrice();
        // observe() extends the tick/liquidity accumulators through idle blocks.
        // An unchanged pool needs no swap to produce a valid current-window TWAP.
        // Insufficient history still reverts in observe; liquidity/deviation checks remain below.
        uint32[] memory ago=new uint32[](2);ago[0]=WINDOW;
        (int56[] memory ticks,uint160[] memory liquidities)=pool.observe(ago);
        if(ticks.length!=2||liquidities.length!=2) revert UnavailablePrice();
        int56 delta;uint160 liquidityDelta;
        // V3 cumulative values intentionally wrap at their native widths.
        unchecked { delta=ticks[1]-ticks[0];liquidityDelta=liquidities[1]-liquidities[0]; }
        if(liquidityDelta==0) revert UnavailablePrice();
        int56 mean=delta/int56(uint56(WINDOW));
        if(delta<0&&delta%int56(uint56(WINDOW))!=0)--mean;
        if(mean < -887272||mean > 887272) revert UnavailablePrice();
        int24 tick=int24(mean);
        int256 difference=int256(spotTick)-tick;
        if(difference>MAX_TICK_DEVIATION||difference < -MAX_TICK_DEVIATION) revert UnavailablePrice();
        uint256 harmonic=(uint256(WINDOW)*type(uint160).max)/(uint256(liquidityDelta)<<32);
        uint256 liquidity=Math.min(harmonic,uint256(pool.liquidity()));
        uint160 sqrtRatio=PancakeTickMath.getSqrtRatioAtTick(tick);
        uint256 virtualBNB=assetIsToken0?Math.mulDiv(liquidity,sqrtRatio,1<<96):Math.mulDiv(liquidity,1<<96,sqrtRatio);
        if(virtualBNB<minimumVirtualBNB) revert UnavailablePrice();
        uint256 quote;
        if(sqrtRatio<=type(uint128).max){
            uint256 ratio=uint256(sqrtRatio)*sqrtRatio;
            quote=assetIsToken0?Math.mulDiv(ratio,1 ether,1<<192):Math.mulDiv(1<<192,1 ether,ratio);
        }else{
            uint256 ratio=Math.mulDiv(sqrtRatio,sqrtRatio,1<<64);
            quote=assetIsToken0?Math.mulDiv(ratio,1 ether,1<<128):Math.mulDiv(1<<128,1 ether,ratio);
        }
        uint256 price=Math.mulDiv(quote,uint256(bnbPrice),1e8);
        if(price==0||price>1e36) revert UnavailablePrice();
        // The DEX window ends at this block; BNB/USD is the independently timestamped input.
        // Never refresh an old BNB/USD round merely because the TWAP was read again.
        updatedAt=bnbAt;startedAt=updatedAt;
        roundId=uint80(updatedAt);answeredInRound=roundId;answer=int256(price);
    }
}
