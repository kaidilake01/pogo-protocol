// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;
import {TestBase} from "./TestBase.sol";
import {PancakeTwapQuoteFeed} from "../../contracts/src/PancakeTwapQuoteFeed.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "../../contracts/internal/QuoteAssetRegistryV3.sol";
import {QuoteAssetRegistryV7} from "../../contracts/src/QuoteAssetRegistry.sol";
contract TwapToken {function decimals() external pure returns(uint8){return 18;}}
contract TwapUsdMock {
 int256 public price=730e8;uint256 public at;uint80 public round=1;uint80 public answered=1;
 constructor(){at=block.timestamp;}
 function decimals() external pure returns(uint8){return 8;}
 function set(int256 p,uint256 t,uint80 r,uint80 a) external {price=p;at=t;round=r;answered=a;}
 function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80){return(round,price,at,at,answered);}
}
contract TwapPoolMock {
 address public token0;address public token1;uint24 public fee=10000;uint128 public liquidity=1000 ether;
 uint32 public at;int24 public spot;int56 public mean;int56 public remainder;bool public missing;
 constructor(address a,address b){token0=a;token1=b;at=uint32(block.timestamp);}
 function set(int24 s,int56 m,int56 r,uint128 l,uint32 t,bool fail) external {spot=s;mean=m;remainder=r;liquidity=l;at=t;missing=fail;}
 function getPool(address,address,uint24) external view returns(address){return address(this);}
 function slot0() external view returns(uint160,int24,uint16,uint16,uint16,uint32,bool){return(0,spot,0,1,1,0,true);}
 function observations(uint256) external view returns(uint32,int56,uint160,bool){return(at,0,0,true);}
 function observe(uint32[] calldata ago) external view returns(int56[] memory t,uint160[] memory l){
  require(!missing,"OLD");t=new int56[](2);l=new uint160[](2);t[1]=mean*int56(uint56(ago[0]))+remainder;
  l[1]=liquidity==0?type(uint160).max:uint160((uint256(ago[0])*(1<<128)+liquidity-1)/liquidity);
 }
}
contract PancakeTwapFeedTest is TestBase {
 TwapToken a;TwapToken b;TwapPoolMock p;TwapUsdMock usd;PancakeTwapQuoteFeed f;
 function setUp() public {vm.warp(10000);a=new TwapToken();b=new TwapToken();p=new TwapPoolMock(address(a),address(b));usd=new TwapUsdMock();f=make(address(p),address(a),address(b),100 ether);}
 function make(address pool,address asset,address wrapped,uint256 minimum) internal returns(PancakeTwapQuoteFeed){return new PancakeTwapQuoteFeed(pool,pool,asset,wrapped,address(usd),minimum);}
 function price() internal view returns(uint256){(,int256 v,,,)=f.latestRoundData();return uint256(v);}
 function testPriceAndRealTimestamp() public {assertEq(price(),730 ether);usd.set(730e8,9900,1,1);(uint80 r,,uint256 started,uint256 at,uint80 answered)=f.latestRoundData();assertEq(at,9900);assertEq(started,at);assertEq(r,answered);}
 function testNegativeTickFloorsTowardMinusInfinity() public {p.set(-1,0,-1,1000 ether,10000,false);assertApprox(price(),729927007299270072992,100000);}
 function testReverseOrdering() public {p=new TwapPoolMock(address(b),address(a));p.set(1,1,0,1000 ether,10000,false);f=make(address(p),address(a),address(b),100 ether);assertApprox(price(),729927007299270072992,100000);}
 function testRejectsStaleBnb() public {vm.warp(10301);vm.expectRevert();f.latestRoundData();}
 function testRejectsFutureBnb() public {usd.set(730e8,10001,1,1);vm.expectRevert();f.latestRoundData();}
 function testRejectsInvalidRound() public {usd.set(730e8,10000,2,1);vm.expectRevert();f.latestRoundData();}
 function testRejectsNegativePrice() public {usd.set(-1,10000,1,1);vm.expectRevert();f.latestRoundData();}
 function testRejectsMissingHistory() public {p.set(0,0,0,1000 ether,10000,true);vm.expectRevert();f.latestRoundData();}
 function testIdlePoolWithValidWindowStillPrices() public {p.set(0,0,0,1000 ether,8199,false);assertEq(price(),730 ether);(,,,uint256 at,)=f.latestRoundData();assertEq(at,10000);}
 function testIdlePoolDoesNotRefreshStaleBnb() public {p.set(0,0,0,1000 ether,1,false);usd.set(730e8,9699,1,1);vm.expectRevert();f.latestRoundData();}
 function testIdlePoolStillRejectsInsufficientHistory() public {p.set(0,0,0,1000 ether,8199,true);vm.expectRevert();f.latestRoundData();}
 function testRejectsThinPool() public {p.set(0,0,0,10 ether,10000,false);vm.expectRevert();f.latestRoundData();}
 function testRejectsSpotManipulation() public {p.set(501,0,0,1000 ether,10000,false);vm.expectRevert();f.latestRoundData();}
 function testRejectsWrongPair() public {TwapToken other=new TwapToken();vm.expectRevert();make(address(p),address(other),address(b),100 ether);}
 function testRejectsWeakMinimum() public {vm.expectRevert();make(address(p),address(a),address(b),99 ether);}
 function testConfiguresRegistryWithoutChangingBnbTerms() public {
  QuoteAssetRegistryV3 source=new QuoteAssetRegistryV3(address(this));
  source.configure(address(0),QuoteAssetRegistry.Asset(address(usd),0,300,18,8,0,true));
  source.configure(address(a),QuoteAssetRegistry.Asset(address(f),0,1800,18,18,0,true));
  QuoteAssetRegistryV7 wrapper=new QuoteAssetRegistryV7(address(source),0.01 ether);
  QuoteAssetRegistry.LaunchQuote memory q=wrapper.quoteLaunch(address(a));
  assertEq(q.assetUsd,730 ether);assertEq(q.target,0.01 ether);
  assertEq(wrapper.quoteLaunch(address(0)).target,0.01 ether);
  assertEq(source.quoteLaunch(address(0)).target,18 ether);
 }
 function testMainnetPepeFeed() public {
  string memory url=vm.envOr("PEPE_FORK_RPC",string(""));if(bytes(url).length==0){vm.skip(true);return;}
  vm.createSelectFork(url);
  PancakeTwapQuoteFeed live=new PancakeTwapQuoteFeed(0xdD82975ab85E745c84e497FD75ba409Ec02d4739,0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865,0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00,0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE,100 ether);
  (,int256 quote,,uint256 at,)=live.latestRoundData();assertTrue(quote>1e9&&quote<1e16);assertLe(block.timestamp-at,1800);
 }
}
