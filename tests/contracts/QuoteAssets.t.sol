// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TestBase} from "./TestBase.sol";
import {QuoteAssetRegistry, IAtlasMultiQuote} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {MultiAssetCurve} from "../../contracts/internal/MultiAssetCurve.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockWBNB, MockV2Factory, MockRouter, MockPair} from "./Mocks.sol";

contract QuoteMock is ERC20 {
    uint8 private immutable dp;
    constructor(uint8 decimals_) ERC20("Stock quote", "STOCK") { dp=decimals_; }
    function decimals() public view override returns(uint8) { return dp; }
    function mint(address to,uint256 amount) external { _mint(to,amount); }
}
contract PriceMock {
    uint8 public decimals=8;
    int256 public answer=700e8;
    uint256 public timestamp;
    bool public eoaOnly;
    constructor() { timestamp=block.timestamp; }
    function set(int256 a,uint256 t) external { answer=a; timestamp=t; }
    function setRestricted() external { eoaOnly=true; }
    function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80) {
        require(!eoaOnly || msg.sender==tx.origin,"EOA_ONLY");
        return(1,answer,timestamp,timestamp,1);
    }
}
contract AtlasMultiMock {
    uint8 public decimals=18;
    IAtlasMultiQuote.Snapshot public snapshot;
    function set(uint80 price,uint48 aggregated,uint48 onchainAt) external {
        snapshot=IAtlasMultiQuote.Snapshot(price,aggregated,onchainAt);
    }
    function fetch(bytes4 id) external view returns(IAtlasMultiQuote.Snapshot memory) {
        require(id==bytes4(uint32(979)),"WRONG_FEED"); return snapshot;
    }
}
contract CurveTokenMock is ERC20 {
    uint16 public buyTaxBps;
    uint16 public sellTaxBps;
    address public pair;
    constructor(address curve,uint16 buy_,uint16 sell_) ERC20("Launch", "LAUNCH") {
        buyTaxBps=buy_; sellTaxBps=sell_; _mint(curve,1_000_000_000 ether);
    }
    function activatePair(address p) external { pair=p; }
    function reservePair(address) external {}
    function burn(uint256 amount) external { _burn(msg.sender,amount); }
}
contract RevenueMock {
    address public asset;
    uint256 public received;
    constructor(address asset_) { asset=asset_; }
    function notifyQuote(uint256 amount) external payable {
        if(asset!=address(0)) IERC20(asset).transferFrom(msg.sender,address(this),amount);
        else require(msg.value==amount);
        received+=amount;
    }
}

contract QuoteAssetsTest is TestBase {
    QuoteAssetRegistry registry;
    PriceMock bnb;
    PriceMock stock;
    QuoteMock quote;
    function setUp() public {
        vm.warp(1_000_000); vm.deal(address(this),100 ether);
        registry=new QuoteAssetRegistry(address(this));
        bnb=new PriceMock(); stock=new PriceMock(); stock.set(140e8,block.timestamp);
        quote=new QuoteMock(6);
        registry.configure(address(0),_asset(address(bnb),18));
        registry.configure(address(quote),_asset(address(stock),6));
    }
    function _asset(address feed,uint8 dp) private pure returns(QuoteAssetRegistry.Asset memory) {
        return QuoteAssetRegistry.Asset(feed,0,3600,dp,8,0,true);
    }
    function testNativeAndSixDecimalStockTenBnbTarget() public view {
        QuoteAssetRegistry.LaunchQuote memory q=registry.quoteLaunch(address(quote));
        assertEq(q.target,50e6); assertEq(q.virtualQuote,125e5);
        assertEq(q.assetUsd,140 ether); assertEq(q.bnbUsd,700 ether);
        q=registry.quoteLaunch(address(0));
        assertEq(q.target,10 ether); assertEq(q.virtualQuote,2.5 ether);
    }
    function testRejectStaleZeroNegativeFutureAndContractRestrictedFeeds() public {
        stock.set(140e8,block.timestamp-3601);
        vm.expectRevert(); registry.quoteLaunch(address(quote));
        stock.set(0,block.timestamp); vm.expectRevert(); registry.quoteLaunch(address(quote));
        stock.set(-1,block.timestamp); vm.expectRevert(); registry.quoteLaunch(address(quote));
        stock.set(140e8,block.timestamp+1); vm.expectRevert(); registry.quoteLaunch(address(quote));
        stock.set(140e8,block.timestamp); stock.setRestricted();
        vm.expectRevert(); registry.configure(address(quote),_asset(address(stock),6));
    }
    function testAtlasMultiUsesAggregationTimeNotOnlyWriteTime() public {
        AtlasMultiMock feed=new AtlasMultiMock();
        feed.set(140 ether,uint48(block.timestamp),uint48(block.timestamp));
        registry.configure(address(quote),QuoteAssetRegistry.Asset(address(feed),bytes4(uint32(979)),120,6,18,2,true));
        assertEq(registry.quoteLaunch(address(quote)).target,50e6);
        feed.set(140 ether,uint48(block.timestamp-121),uint48(block.timestamp));
        vm.expectRevert(); registry.quoteLaunch(address(quote));
    }
    function testConfigCannotLieAboutDecimalsAndCannotBeChangedByStranger() public {
        vm.expectRevert(); registry.configure(address(quote),_asset(address(stock),18));
        vm.prank(address(0x111)); vm.expectRevert(); registry.setEnabled(address(quote),false);
        bytes32 before_=registry.configHash(address(quote));
        registry.setEnabled(address(quote),false);
        assertTrue(before_!=registry.configHash(address(quote)));
        vm.expectRevert(); registry.quoteLaunch(address(quote));
        (uint256 price,)=registry.priceUsd(address(quote)); assertEq(price,140 ether);
    }
    function _curve(address asset,uint8 dp,uint256 target,uint16 buyTax,uint16 sellTax)
        private returns(MultiAssetCurve c,CurveTokenMock t,RevenueMock v) {
        c=MultiAssetCurve(Clones.clone(address(new MultiAssetCurve())));
        t=new CurveTokenMock(address(c),buyTax,sellTax); v=new RevenueMock(asset);
        MockRouter router=new MockRouter(address(new MockWBNB()),address(new MockV2Factory()));
        c.initialize(MultiAssetCurve.Init(address(t),address(v),address(0x777),address(router),asset,dp,target/4,target));
    }
    function testErc20BuySellTaxAndGraduationSameAsset() public {
        (MultiAssetCurve c,CurveTokenMock t,RevenueMock v)=_curve(address(quote),6,50e6,200,500);
        quote.mint(address(this),100e6); quote.approve(address(c),type(uint256).max);
        MultiAssetCurve.BuyQuote memory q=c.quoteBuy(1e6);
        c.buy(1e6,q.tokens,block.timestamp,address(this));
        assertEq(t.balanceOf(address(this)),q.tokens); assertEq(v.received(),20_000);
        t.approve(address(c),type(uint256).max);
        (uint256 out,uint256 fee,uint256 tax)=c.quoteSell(q.tokens/2);
        uint256 before_=quote.balanceOf(address(this));
        c.sell(q.tokens/2,out,block.timestamp,address(this));
        assertEq(quote.balanceOf(address(this))-before_,out);
        assertEq(v.received(),20_000+tax); assertEq(c.platformCredit(),10_000+fee);
        q=c.quoteBuy(90e6); before_=quote.balanceOf(address(this));
        c.buy(90e6,q.tokens,block.timestamp,address(this));
        assertEq(before_-quote.balanceOf(address(this)),q.used); assertEq(c.reserveQuote(),50e6);
        uint256 finalSpot=c.spotPrice();
        c.graduate(); assertTrue(c.graduated());
        MockPair p=MockPair(c.pair());
        assertEq(quote.balanceOf(address(p)),50e6); assertTrue(p.balanceOf(address(0xdead))>0);
        uint256 dexSpot=quote.balanceOf(address(p))*1e30/t.balanceOf(address(p));
        assertApprox(finalSpot,dexSpot,1);
        assertApprox(t.totalSupply(),960_000_000 ether,1 ether);
        c.claimPlatform(); assertEq(quote.balanceOf(address(0x777)),10_000+fee+q.platformFee);
    }
    function testNativeRefundAndNoOracleNeededAfterCreation() public {
        (MultiAssetCurve c,CurveTokenMock t,)=_curve(address(0),18,10 ether,0,0);
        uint256 before_=address(this).balance;
        MultiAssetCurve.BuyQuote memory q=c.quoteBuy(20 ether);
        c.buy{value:20 ether}(20 ether,q.tokens,block.timestamp,address(this));
        assertEq(before_-address(this).balance,q.used); assertEq(c.reserveQuote(),10 ether);
        assertEq(q.tax,0); assertApprox(t.balanceOf(address(this)),800_000_000 ether,1);
        stock.set(-1,0); bnb.set(-1,0); registry.setEnabled(address(quote),false);
        c.graduate(); assertTrue(c.graduated());
    }
    function testFuzzRoundTripCannotDrainCurve(uint96 raw,uint16 taxRaw) public {
        uint256 amount=uint256(raw)%8 ether+1e12;
        uint16 tax=taxRaw%501;
        (MultiAssetCurve c,CurveTokenMock t,)=_curve(address(0),18,10 ether,tax,tax);
        uint256 start=address(this).balance;
        c.buy{value:amount}(amount,0,block.timestamp,address(this));
        t.approve(address(c),type(uint256).max);
        uint256 tokens=t.balanceOf(address(this));
        (uint256 out,,)=c.quoteSell(tokens);
        c.sell(tokens,out,block.timestamp,address(this));
        assertLe(address(this).balance,start);
        assertEq(address(c).balance,c.reserveQuote()+c.platformCredit());
        assertEq(t.balanceOf(address(c)),1_000_000_000 ether);
    }
}

contract QuoteAssetsForkTest is TestBase {
    function testBscPublicAtlasStockQuotesFromConsumerContract() public {
        if(vm.envOr("RUN_BSC_FORK",uint256(0))==0) { vm.skip(true); return; }
        vm.createSelectFork(vm.envOr("BSC_RPC_URL",string("https://bsc-dataseed.bnbchain.org")));
        QuoteAssetRegistry r=new QuoteAssetRegistry(address(this));
        r.configure(address(0),QuoteAssetRegistry.Asset(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE,0,3600,18,8,0,true));
        // Apple bStock; publicly readable Atlas multi feed #979. No HTTP price update or API key.
        address apple=0x431a3BEE82E2ca41e49895CbECE5bB0F76A89b7A;
        r.configure(apple,QuoteAssetRegistry.Asset(0xEAcE519ebB14fB8404fA6DdD23C3b34abaDE44aa,bytes4(uint32(979)),300,18,18,2,true));
        QuoteAssetRegistry.LaunchQuote memory a=r.quoteLaunch(apple);
        assertTrue(a.assetUsd>0); assertApprox(a.target*a.assetUsd/1e18,a.bnbUsd*10,1000);
        address nvda=0x02Fca66C1D1aFB4E2A7884261eB00F63598a7436;
        r.configure(nvda,QuoteAssetRegistry.Asset(0xf25Af12920D408bAf6211e9e90eDa89DF3D8CCDa,0,300,18,18,1,true));
        QuoteAssetRegistry.LaunchQuote memory n=r.quoteLaunch(nvda);
        assertTrue(n.assetUsd>0); assertApprox(n.target*n.assetUsd/1e18,n.bnbUsd*10,1000);
    }
}
