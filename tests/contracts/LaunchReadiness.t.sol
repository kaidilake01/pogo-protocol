// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchEconomicsV2Test} from './LaunchEconomicsV2.t.sol';
import {LaunchFactoryV3} from '../../contracts/src/LaunchFactoryV3.sol';
import {LaunchTypes} from '../../contracts/src/v3/LaunchTypes.sol';
import {LaunchTokenV3} from '../../contracts/src/v3/LaunchTokenV3.sol';
import {MultiAssetCurve} from '../../contracts/src/v3/MultiAssetCurve.sol';
import {RevenueVault} from '../../contracts/src/v3/RevenueVault.sol';
import {MockPair,MockV2Factory} from './Mocks.sol';

contract LaunchReadinessTest is LaunchEconomicsV2Test {
 function testReadinessRejectsPrematurePairFundingAndGraduates() public {
  LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
  LaunchTokenV3 token=LaunchTokenV3(f.createTokenV3{value:.01 ether}(p));
  (,address poolAddr,,)=f.projects(address(token));MultiAssetCurve pool=MultiAssetCurve(poolAddr);
  address earlyPair=MockV2Factory(router.factory()).getPair(address(token),address(wrapped));
  // A buyer supplies the future primary pair as the recipient, bypassing wallet transfer restrictions.
  vm.expectRevert(LaunchTokenV3.CurveTransfersRestricted.selector);
  pool.buy{value:.001 ether}(.001 ether,1,block.timestamp,earlyPair);
  wrapped.deposit{value:.001 ether}();wrapped.transfer(earlyPair,.001 ether);MockPair(earlyPair).sync();
  assertEq(MockPair(earlyPair).totalSupply(),0);
  pool.buy{value:12 ether}(12 ether,1,block.timestamp,address(this));assertEq(pool.progressBps(),10000);
  pool.graduate();assertTrue(pool.graduated());
 }
 function testReadinessCreator() public {_exercise(0);}
 function testReadinessLiquidityCreator() public {_exercise(1);}
 function testReadinessHolderCreator() public {_exercise(2);}
 function testReadinessBurnCreator() public {_exercise(3);}
 function testReadinessBalanced() public {_exercise(4);}
 function testReadinessNoTax() public {_exercise(5);}
 function testReadinessSellOnlyLiquidity() public {_exercise(6);}
 function _exercise(uint256 i) private {
  uint16[4][7] memory shares=[uint16[4]([10000,0,0,0]),[3333,0,0,6667],[3000,0,7000,0],[3000,7000,0,0],[2500,2500,2500,2500],[10000,0,0,0],[0,0,0,10000]];
   LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
   uint16 buyTax=i==5||i==6?0:300;uint16 sellTax=i==5?0:i==6?500:300;
   p.tax=LaunchTypes.Tax(buyTax,sellTax,shares[i][0],shares[i][1],shares[i][2],shares[i][3],RECIPIENT,0);
   LaunchFactoryV3.DeveloperBuy memory first;first.amount=.2 ether;first.payWithBNB=true;first.minTokens=1;first.deadline=block.timestamp;
   LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:.21 ether}(p,first));
   (,address poolAddr,address vaultAddr,)=f.projects(address(token));
   MultiAssetCurve pool=MultiAssetCurve(poolAddr);RevenueVault vault=RevenueVault(payable(vaultAddr));
   assertTrue(token.balanceOf(address(this))>0);
   address holder=address(uint160(0xB000+i));pool.buy{value:.1 ether}(.1 ether,1,block.timestamp,holder);
   token.approve(poolAddr,type(uint256).max);
   uint256 sale=token.balanceOf(address(this))/10;uint256 beforeBNB=address(this).balance;
   (uint256 expected,,)=pool.quoteSell(sale);pool.sell(sale,expected,block.timestamp,address(this));assertEq(address(this).balance-beforeBNB,expected);
   if(vault.burnBudget()>0){uint256 beforeBurn=token.totalBurned();vault.executeBuyback(vault.burnBudget()/2,1,block.timestamp);assertTrue(token.totalBurned()>beforeBurn);}
   uint256 earned=vault.earned(address(this),address(0));
   if(earned>0){beforeBNB=address(this).balance;vault.claim(address(0),address(this));assertEq(address(this).balance-beforeBNB,earned);}
   pool.buy{value:12 ether}(12 ether,1,block.timestamp,address(this));pool.graduate();assertTrue(pool.graduated());
   address[] memory path=new address[](2);path[0]=address(wrapped);path[1]=address(token);
   uint256 recipientBefore=token.balanceOf(RECIPIENT);
   router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:.1 ether}(1,path,holder,block.timestamp);
   path[0]=address(token);path[1]=address(wrapped);token.approve(address(router),type(uint256).max);
   beforeBNB=address(this).balance;router.swapExactTokensForETHSupportingFeeOnTransferTokens(token.balanceOf(address(this))/100,1,path,address(this),block.timestamp);assertTrue(address(this).balance>beforeBNB);
   if(p.tax.recipientBps>0&&(buyTax>0||sellTax>0))assertTrue(token.balanceOf(RECIPIENT)>recipientBefore);
   assertEq(token.balanceOf(address(token)),0);
   if(vault.liquidityBudget(address(0))>0&&vault.liquidityBudget(address(token))>0){
    uint256 locked=MockPair(pool.pair()).balanceOf(address(0xdead));
    vault.addLiquidity(type(uint256).max,type(uint256).max,1);
    assertTrue(MockPair(pool.pair()).balanceOf(address(0xdead))>locked);
   }
   earned=vault.earned(address(this),address(token));
   if(earned>0){uint256 beforeTokens=token.balanceOf(address(this));vault.claim(address(token),address(this));assertEq(token.balanceOf(address(this))-beforeTokens,earned);}
   assertTrue(address(vault).balance>=vault.burnBudget()+vault.liquidityBudget(address(0))+vault.earned(holder,address(0))+vault.earned(address(this),address(0))+vault.queued(address(0)));
 }
}
