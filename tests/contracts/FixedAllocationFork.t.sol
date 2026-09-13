// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {TestBase} from "./TestBase.sol";
import {LaunchFactoryV8} from "../../contracts/src/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {ReflowCurveDeployer} from "../../contracts/src/MiningCurveDeployer.sol";
import {ReflowCurve} from "../../contracts/src/MiningCurve.sol";
import {FixedAllocationMining,FixedAllocationMiningDeployer} from "../../contracts/src/Mining.sol";
import {QuoteRevenueVault,QuoteVaultDeployer} from "../../contracts/src/RevenueVault.sol";
import {MiningRevenueVault} from "../../contracts/internal/MiningRevenueVault.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";
import {BNBQuoteAdapter} from "../../contracts/src/BNBQuoteAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWBNB} from "../../contracts/internal/Interfaces.sol";
interface IReflowRouter {
 function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256,address[] calldata,address,uint256) external payable;
 function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[] calldata,address,uint256) external;
 function addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256) external returns(uint256,uint256,uint256);
 function addLiquidityETH(address,uint256,uint256,uint256,address,uint256) external payable returns(uint256,uint256,uint256);
 function removeLiquidityETHSupportingFeeOnTransferTokens(address,uint256,uint256,uint256,address,uint256) external returns(uint256);
 function removeLiquidity(address,address,uint256,uint256,uint256,address,uint256) external returns(uint256,uint256);
}
interface IV2BurnPair {function burn(address) external returns(uint256,uint256);function token0() external view returns(address);function getReserves() external view returns(uint112,uint112,uint32);}
interface VmReflowForkTime {function getBlockTimestamp() external view returns(uint256);}
contract FixedAllocationForkTest is TestBase {
 address constant WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
 IReflowRouter constant router=IReflowRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
 event ReflowEvidence(address token,address asset,address pair,uint256 rewardBudget,uint256 creationGas,uint256 claimed);
 function testProductionTargetBnbV2Lifecycle() public {
  if(vm.envOr('RUN_BSC_FORK',uint256(0))==0){vm.skip(true);return;}
  vm.createSelectFork(vm.envOr('BSC_RPC_URL',string('https://bsc-mainnet.public.blastapi.io')));vm.deal(address(this),100 ether);
  uint256 forkTimestamp=VmReflowForkTime(address(vm)).getBlockTimestamp();
  LaunchFactoryV8 f=LaunchFactoryV8(payable(0x0abc6174ee9f9600243D14F83E215993b8BbABEb));
  address[4] memory assets=[address(0),0x205812CdBed920aFf76C6580abD681a46D11efc7,0x431a3BEE82E2ca41e49895CbECE5bB0F76A89b7A,0xbe9D156892E55e7154BcD3cB0FEA677F9D3103E1];
  uint256 salt;(address td,bytes32 hash)=f.tokenDeploymentConfig();
  // Exercise BNB launches with zero and nonzero project taxes.
  for(uint256 j;j<1;j++)for(uint256 taxed;taxed<2;taxed++){
   vm.warp(forkTimestamp);
   address asset=assets[j];QuoteAssetRegistry.LaunchQuote memory q=QuoteAssetRegistry(address(f.quoteRegistry())).quoteLaunch(asset);
   LaunchFactoryV3.CreateParamsV3 memory p;p.name='Reflow fork';p.symbol='FLY';p.metadataURI='ipfs://takeoff-fork';p.quoteAsset=asset;p.minTarget=q.target;p.maxTarget=q.target;
   p.expectedConfig=f.templateConfigHash(asset,12);p.tax=LaunchTypes.Tax(taxed==0?0:300,taxed==0?0:300,4000,2000,3000,1000,address(this),0);
   for(;;salt++){
    uint256 free;assembly('memory-safe'){free:=mload(0x40)}p.salt=bytes32(salt);
    address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),td,keccak256(abi.encode(address(this),p.salt)),hash)))));
    assembly('memory-safe'){mstore(0x40,free)}if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0){salt++;break;}
   }
   uint256 beforeGas=gasleft();address token;
   if(taxed==1){
    LaunchFactoryV3.DeveloperBuy memory buy=LaunchFactoryV3.DeveloperBuy(.001 ether,1,1,block.timestamp,true,route(asset));
    token=f.createTokenAndBuyWithTemplateV8{value:.001 ether}(p,buy,12);
   }else token=f.createTokenWithTemplateV8(p,12);
   uint256 creationGas=beforeGas-gasleft();assertTrue(creationGas*130/100+100000<16_777_216);
   (,address pool,address vault,)=f.projects(token);ReflowCurve c=ReflowCurve(pool);FixedAllocationMining m=FixedAllocationMining(c.stakingPool());
   assertEq(c.VERSION(),11);assertEq(m.VERSION(),14);assertEq(m.penaltyRecipient(),address(0xdead));
   if(asset==address(0)){assertEq(c.graduationTarget(),6.666 ether);c.buy{value:8 ether}(8 ether,1,block.timestamp,address(this));}
   else{
    BNBQuoteAdapter(f.bnbAdapter()).convertBNB{value:.03 ether}(asset,1,block.timestamp,address(this),route(asset));
    IERC20(asset).approve(pool,type(uint256).max);c.buy(q.target*2,1,block.timestamp,address(this));
   }
   c.graduate();address pair=c.pair();
   QuoteRevenueVault v=QuoteRevenueVault(payable(vault));assertEq(v.DIVIDEND_ASSET_VERSION(),1);
   assertEq(v.earned(address(this),token),0);assertEq(v.recipientCredit(token),0);
   if(taxed==1){
    address[] memory swapPath=new address[](2);swapPath[0]=asset==address(0)?WBNB:asset;swapPath[1]=token;
    (uint112 r0,uint112 r1,)=IV2BurnPair(pair).getReserves();
    uint256 quoteInput=(IV2BurnPair(pair).token0()==token?uint256(r1):uint256(r0))/100;
    if(asset==address(0))router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:quoteInput}(1,swapPath,address(this),block.timestamp);
    else {IERC20(asset).approve(address(router),quoteInput);router.swapExactTokensForTokensSupportingFeeOnTransferTokens(quoteInput,1,swapPath,address(this),block.timestamp);}
    swapPath[0]=token;swapPath[1]=asset==address(0)?WBNB:asset;
    uint256 sellAmount=IERC20(token).balanceOf(address(this))/100;
    IERC20(token).approve(address(router),sellAmount);router.swapExactTokensForTokensSupportingFeeOnTransferTokens(sellAmount,1,swapPath,address(this),block.timestamp);
    assertTrue(v.pendingTokenRevenue()>0);assertEq(v.earned(address(this),token),0);
    assertEq(v.runAutomation(),4);vm.warp(block.timestamp+181);
    uint256 earnedBefore=v.earned(address(this),asset);uint256 convertedBefore=v.totalQuoteRevenueConverted();
    uint256 actions=v.runAutomation();assertTrue(actions&8!=0);assertTrue(v.totalQuoteRevenueConverted()>convertedBefore);
    assertTrue(v.earned(address(this),asset)>earnedBefore);assertEq(v.totalDistributed(token),0);
    assertEq(v.earned(address(this),token),0);vm.expectRevert(QuoteRevenueVault.InvalidConfig.selector);v.claim(token,address(this));
    v.claim(asset,address(this));assertEq(v.earned(address(this),asset),0);
   }
assertEq(m.poolState(0).budget,m.rewardBudget()/25);assertEq(m.poolState(1).budget,m.rewardBudget()*4/25);assertEq(m.poolState(2).budget,m.rewardBudget()-m.rewardBudget()/25-m.rewardBudget()*4/25);assertEq(m.lpToken(),pair);assertTrue(IERC20(pair).balanceOf(address(0xdead))>0);
   assertTrue(m.rewardBudget()>179_000_000 ether && m.rewardBudget()<180_000_000 ether);assertEq(IERC20(token).balanceOf(pool),m.rewardBudget());
   address settled=asset==address(0)?WBNB:asset;
   if(asset==address(0))IWBNB(WBNB).deposit{value:.03 ether}();
   IERC20(token).approve(address(router),type(uint256).max);IERC20(settled).approve(address(router),type(uint256).max);
   // Match the website's exact ratio, 1% minima, and taxed LP estimate.
   (uint112 r0,uint112 r1,)=IV2BurnPair(pair).getReserves();bool first=IV2BurnPair(pair).token0()==token;
   uint256 rt=first?r0:r1;uint256 rq=first?r1:r0;uint256 qa=q.target/100;uint256 ta=qa*rt/rq;
   uint256 supply=IERC20(pair).totalSupply();uint256 net=ta-ta*(taxed==0?0:300)/10000;
   uint256 expectedLP=net*supply/rt;uint256 quoteLP=(ta*rq/rt)*supply/rq;if(quoteLP<expectedLP)expectedLP=quoteLP;
   uint256 lp;
   if(asset==address(0)){(,,lp)=router.addLiquidityETH{value:qa}(token,ta,ta*99/100,qa*99/100,address(this),block.timestamp);}
   else{(,,lp)=router.addLiquidity(token,settled,ta,qa,ta*99/100,qa*99/100,address(this),block.timestamp);}
   assertEq(lp,expectedLP);assertEq(IERC20(pair).balanceOf(address(this)),lp);
   assertTrue(lp>0);IERC20(token).approve(address(m),type(uint256).max);IERC20(pair).approve(address(m),type(uint256).max);
   uint256 holding=MiningRevenueVault(payable(vault)).holderBalance(address(this));
   m.stake(1000 ether,false);m.stake(1000 ether,true);m.stakeLP(lp);
   assertEq(m.balanceOf(address(this)),2000 ether);assertEq(MiningRevenueVault(payable(vault)).holderBalance(address(this)),holding);
   vm.warp(VmReflowForkTime(address(vm)).getBlockTimestamp()+12 hours);
   uint256 treasuryBefore=IERC20(pair).balanceOf(address(0xdead));
   (uint112 oldR0,uint112 oldR1,)=IV2BurnPair(pair).getReserves();uint256 oldSupply=IERC20(pair).totalSupply();uint256 feeBalance=IERC20(pair).balanceOf(f.treasury());
   m.withdrawLPEarly(0,lp/2);
   (uint112 newR0,uint112 newR1,)=IV2BurnPair(pair).getReserves();assertEq(oldR0,newR0);assertEq(oldR1,newR1);assertEq(oldSupply,IERC20(pair).totalSupply());assertEq(feeBalance,IERC20(pair).balanceOf(f.treasury()));
   assertEq(IERC20(pair).balanceOf(address(0xdead))-treasuryBefore,(lp/2)/10);assertTrue(m.claimedRewards()>0);
   vm.warp(VmReflowForkTime(address(vm)).getBlockTimestamp()+12 hours);
   m.withdrawLocked(0,1000 ether);m.withdrawFlexible(1000 ether);m.withdrawLP(0,lp-lp/2);
   assertEq(m.balanceOf(address(this)),0);assertEq(m.stakeOf(2,address(this)),0);assertEq(IERC20(pair).balanceOf(address(m)),0);
   assertEq(c.miningReleased(),m.claimedRewards());assertEq(MiningRevenueVault(payable(vault)).holderBalance(address(this)),IERC20(token).balanceOf(address(this)));
   // Actual V2 liquidity removal after farming; no synthetic LP balances.
   uint256 exitLP=IERC20(pair).balanceOf(address(this));IERC20(pair).approve(address(router),exitLP);
   uint256 tokenBefore=IERC20(token).balanceOf(address(this));uint256 quoteBefore=asset==address(0)?address(this).balance:IERC20(settled).balanceOf(address(this));
   uint256 grossToken=exitLP*IERC20(token).balanceOf(pair)/IERC20(pair).totalSupply();uint256 grossQuote=exitLP*IERC20(settled).balanceOf(pair)/IERC20(pair).totalSupply();
   if(asset==address(0))router.removeLiquidityETHSupportingFeeOnTransferTokens(token,exitLP,grossToken*99/100,grossQuote*99/100,address(this),block.timestamp);
   else router.removeLiquidity(token,settled,exitLP,grossToken*99/100,grossQuote*99/100,address(this),block.timestamp);
   assertTrue(IERC20(token).balanceOf(address(this))>tokenBefore);assertTrue((asset==address(0)?address(this).balance:IERC20(settled).balanceOf(address(this)))>quoteBefore);
   assertEq(IERC20(pair).balanceOf(address(this)),0);
   emit ReflowEvidence(token,asset,pair,m.rewardBudget(),creationGas,m.claimedRewards());
  }
 }
 function route(address asset) private pure returns(BNBQuoteAdapter.Route memory r){
  if(asset==address(0))return BNBQuoteAdapter.Route(0,new address[](0),'');
  bytes memory path=asset==0xbe9D156892E55e7154BcD3cB0FEA677F9D3103E1?abi.encodePacked(WBNB,uint24(2500),asset):abi.encodePacked(WBNB,uint24(100),address(0x55d398326f99059fF775485246999027B3197955),asset==0x205812CdBed920aFf76C6580abD681a46D11efc7?uint24(100):uint24(2500),asset);
  return BNBQuoteAdapter.Route(2,new address[](0),path);
 }
}
