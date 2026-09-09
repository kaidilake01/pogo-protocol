// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchEconomicsV2Test} from './LaunchEconomicsV2.t.sol';
import {LaunchFactoryV3} from '../../contracts/src/LaunchFactoryV3.sol';
import {LaunchTypes} from '../../contracts/src/v3/LaunchTypes.sol';
import {LaunchTokenV3} from '../../contracts/src/v3/LaunchTokenV3.sol';
import {MultiAssetCurve} from '../../contracts/src/v3/MultiAssetCurve.sol';
import {RevenueVault} from '../../contracts/src/v3/RevenueVault.sol';
import {MockPair} from './Mocks.sol';
contract AutomaticRevenueTest is LaunchEconomicsV2Test {
 function _launch(bool stock,bool burn) private returns(LaunchTokenV3 t,MultiAssetCurve c,RevenueVault v){
  LaunchFactoryV3.CreateParamsV3 memory p=_params(stock?address(quote):address(0),RECIPIENT);
  p.tax=LaunchTypes.Tax(300,300,0,burn?10000:0,0,burn?0:10000,RECIPIENT,0);
  t=LaunchTokenV3(f.createTokenV3{value:.01 ether}(p));(,address pool,address vault,)=f.projects(address(t));c=MultiAssetCurve(pool);v=RevenueVault(payable(vault));
  if(stock){quote.mint(address(this),100 ether);quote.approve(pool,type(uint256).max);c.buy(60 ether,1,block.timestamp,address(this));}
  else c.buy{value:12 ether}(12 ether,1,block.timestamp,address(this));
 }
 function testAutomaticNativeQuoteOnlyLp() public {_quoteOnly(false);}
 function testAutomaticStockQuoteOnlyLp() public {_quoteOnly(true);}
 function _quoteOnly(bool stock) private {
  (LaunchTokenV3 t,MultiAssetCurve c,RevenueVault v)=_launch(stock,false);c.graduate();
  assertEq(v.liquidityBudget(address(t)),0);uint256 before_=MockPair(c.pair()).balanceOf(address(0xdead));
  vm.prank(address(0x999));assertEq(v.runAutomation(),4);vm.warp(block.timestamp+180);
  vm.prank(address(0x999));assertEq(v.runAutomation(),6);
  assertTrue(MockPair(c.pair()).balanceOf(address(0xdead))>before_);
  assertEq(v.runAutomation(),0);assertEq(v.recipientCredit(stock?address(quote):address(0)),0);
 }
 function testAutomaticTokenOnlyLpAfterSellAndQuoteExhaustion() public {
  LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);p.tax=LaunchTypes.Tax(0,500,0,0,0,10000,RECIPIENT,0);
  LaunchTokenV3 t=LaunchTokenV3(f.createTokenV3{value:.01 ether}(p));(,address a,address b,)=f.projects(address(t));MultiAssetCurve c=MultiAssetCurve(a);RevenueVault v=RevenueVault(payable(b));
  c.buy{value:12 ether}(12 ether,1,block.timestamp,address(this));c.graduate();
  address[] memory path=new address[](2);path[0]=address(t);path[1]=address(wrapped);t.approve(address(router),type(uint256).max);
  router.swapExactTokensForETHSupportingFeeOnTransferTokens(t.balanceOf(address(this))/100,1,path,address(this),block.timestamp);
  assertEq(v.liquidityBudget(address(0)),0);assertTrue(v.liquidityBudget(address(t))>0);
  uint256 before_=MockPair(c.pair()).balanceOf(address(0xdead));assertEq(v.runAutomation(),4);vm.warp(block.timestamp+180);assertEq(v.runAutomation(),6);
  assertTrue(MockPair(c.pair()).balanceOf(address(0xdead))>before_);
 }
 function testAutomaticCurveBuybackIsPermissionlessAndRateLimited() public {
  LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);p.tax=LaunchTypes.Tax(300,300,2500,5000,2500,0,RECIPIENT,0);
  LaunchTokenV3 t=LaunchTokenV3(f.createTokenV3{value:.01 ether}(p));(,address a,address b,)=f.projects(address(t));MultiAssetCurve c=MultiAssetCurve(a);RevenueVault v=RevenueVault(payable(b));
  c.buy{value:1 ether}(1 ether,1,block.timestamp,address(this));uint256 rewards=v.earned(address(this),address(0));uint256 before_=t.totalBurned();
  vm.prank(address(0x999));assertEq(v.runAutomation(),1);assertTrue(t.totalBurned()>before_);assertEq(v.runAutomation(),0);
  assertGe(v.earned(address(this),address(0)),rewards);assertEq(address(v).balance>=v.burnBudget()+v.earned(address(this),address(0))?1:0,1);
 }
 function testAutomaticDexBuybackAndPriceManipulationDeferral() public {
  (LaunchTokenV3 t,MultiAssetCurve c,RevenueVault v)=_launch(false,true);c.graduate();assertEq(v.runAutomation(),4);
  vm.warp(block.timestamp+180);uint256 budget=v.burnBudget();uint256 burned=t.totalBurned();
  // Donate and sync in the current block: spot changes but the historical average does not.
  wrapped.deposit{value:1 ether}();wrapped.transfer(c.pair(),1 ether);MockPair(c.pair()).sync();
  assertEq(v.runAutomation(),4);assertEq(v.burnBudget(),budget);assertEq(t.totalBurned(),burned);
  vm.warp(v.observationAt()+180);assertEq(v.runAutomation(),5);assertTrue(t.totalBurned()>burned);
 }
 function testFuturePairCannotReceiveVaultPayoutOrDirectCurveBuy() public {
  (LaunchTokenV3 t,MultiAssetCurve c,RevenueVault v)=_launch(false,false);
  address blocked=t.launchPair();vm.prank(address(v));vm.expectRevert(LaunchTokenV3.CurveTransfersRestricted.selector);t.transfer(blocked,0);
  c.graduate();assertTrue(c.graduated());
 }
}
