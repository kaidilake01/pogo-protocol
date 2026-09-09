// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchV3Test} from "./LaunchV3.t.sol";
import {QuoteAssetRegistry} from "../../contracts/src/QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV2} from "../../contracts/src/QuoteAssetRegistryV2.sol";
import {QuoteMock,PriceMock} from "./QuoteAssets.t.sol";
import {TestBase} from "./TestBase.sol";
import {MultiAssetCurve} from "../../contracts/src/v3/MultiAssetCurve.sol";
import {LaunchTokenV3} from "../../contracts/src/v3/LaunchTokenV3.sol";
import {LaunchFactoryV3} from "../../contracts/src/LaunchFactoryV3.sol";
import {MockPair} from "./Mocks.sol";

// Rerun every creation/fee/refund/tax/graduation invariant against the updated curve opening value.
contract LaunchEconomicsV2Test is LaunchV3Test {
 function _expectedInitialBuy() internal pure override returns(uint256){return uint256(1_000_000_000 ether)*97/647;}
 function setUp() public virtual override {
  super.setUp();
  QuoteAssetRegistryV2 next=new QuoteAssetRegistryV2(address(this));
  PriceMock bnb=new PriceMock();PriceMock stock=new PriceMock();stock.set(140e8,block.timestamp);
  next.configure(address(0),QuoteAssetRegistry.Asset(address(bnb),0,3600,18,8,0,true));
  next.configure(address(quote),QuoteAssetRegistry.Asset(address(stock),0,3600,18,8,0,true));
  f.setTemplatesV3(address(next),f.tokenImplementationV3(),f.vaultImplementationV3(),f.poolImplementationV3());
  registry=next;
 }
 function testInitialFdvIndependentFromGraduationAndSixDecimals() public {
  QuoteAssetRegistry.LaunchQuote memory q=registry.quoteLaunch(address(0));
  assertEq(q.target,10 ether);assertEq(q.virtualQuote,5.5 ether);
  QuoteMock six=new QuoteMock(6);PriceMock feed=new PriceMock();feed.set(140e8,block.timestamp);
  registry.configure(address(six),QuoteAssetRegistry.Asset(address(feed),0,3600,6,8,0,true));
  q=registry.quoteLaunch(address(six));assertEq(q.target,50e6);assertEq(q.virtualQuote,275e5);
 }
 function testNewCurveGraduationPriceContinuityAndFrozenLegacyV3() public {
  address newRegistry=address(registry);
  QuoteAssetRegistry old=new QuoteAssetRegistry(address(this));PriceMock feed=new PriceMock();
  old.configure(address(0),QuoteAssetRegistry.Asset(address(feed),0,3600,18,8,0,true));
  f.setTemplatesV3(address(old),f.tokenImplementationV3(),f.vaultImplementationV3(),f.poolImplementationV3());
  registry=old;
  LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
  address oldToken=f.createTokenV3{value:.01 ether}(p);
  (,address oldPool,,)=f.projects(oldToken);
  f.setTemplatesV3(newRegistry,f.tokenImplementationV3(),f.vaultImplementationV3(),f.poolImplementationV3());
  registry=QuoteAssetRegistry(newRegistry);
  assertEq(MultiAssetCurve(oldPool).virtualQuote(),2.5 ether);
  vm.expectRevert();f.createTokenV3{value:.01 ether}(p); // Stale settings cannot silently change launch economics.
  p=_params(address(0),RECIPIENT);
  address token=f.createTokenV3{value:.01 ether}(p);(,address pool,,)=f.projects(token);
  MultiAssetCurve c=MultiAssetCurve(pool);assertEq(c.virtualQuote(),5.5 ether);
  c.buy{value:12 ether}(12 ether,1,block.timestamp,address(this));
  assertEq(c.reserveQuote(),10 ether);uint256 finalSpot=c.spotPrice();
  c.graduate();assertTrue(c.graduated());
  assertTrue(MockPair(c.pair()).balanceOf(address(0xdead))>0);
  uint256 dexSpot=10 ether*1e18/LaunchTokenV3(token).balanceOf(c.pair());
  assertApprox(finalSpot,dexSpot,1);
  assertEq(MultiAssetCurve(oldPool).virtualQuote(),2.5 ether);
 }
}
