// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchV3Fixture} from "./LaunchV3.t.sol";
import {TestBase} from "./TestBase.sol";
import {QuoteMock,PriceMock} from "./QuoteAssets.t.sol";
import {MockPair,MockRouter,MockWBNB} from "./Mocks.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LaunchFactory} from "../../contracts/internal/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {LaunchFactoryV4} from "../../contracts/internal/LaunchFactoryV4.sol";
import {LaunchFactoryV5} from "../../contracts/internal/LaunchFactoryV5.sol";
import {LaunchToken} from "../../contracts/internal/LaunchToken.sol";
import {DividendVault} from "../../contracts/internal/DividendVault.sol";
import {BondingCurve} from "../../contracts/internal/BondingCurve.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "../../contracts/internal/QuoteAssetRegistryV3.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";
import {LaunchTokenV3} from "../../contracts/internal/LaunchTokenV3.sol";
import {MultiAssetCurve} from "../../contracts/internal/MultiAssetCurve.sol";
import {RevenueVault} from "../../contracts/internal/RevenueVault.sol";
import {BNBQuoteAdapter} from "../../contracts/src/BNBQuoteAdapter.sol";
import {StandaloneVaultDeployer} from "../../contracts/internal/StandaloneVaultDeployer.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {StandardTokenDeployer} from "../../contracts/src/TokenDeployer.sol";
import {StandardCurveDeployer} from "../../contracts/internal/StandardCurveDeployer.sol";
import {StandardCurve} from "../../contracts/internal/StandardCurve.sol";

contract PredictablePair is MockPair {
    constructor() MockPair(PredictableFactory(msg.sender).a(),PredictableFactory(msg.sender).b()) {}
}
contract PredictableFactory {
    address public a;address public b;
    mapping(address=>mapping(address=>address)) public getPair;
    function INIT_CODE_PAIR_HASH() external pure returns(bytes32){return keccak256(type(PredictablePair).creationCode);}
    function createPair(address a_,address b_) external returns(address p){
        require(a_!=b_&&getPair[a_][b_]==address(0));
        (a,b)=a_<b_?(a_,b_):(b_,a_);
        p=address(new PredictablePair{salt:keccak256(abi.encodePacked(a,b))}());
        getPair[a_][b_]=p;getPair[b_][a_]=p;
    }
}

contract StandardCurveTest is TestBase {
    LaunchFactoryV5 f;QuoteAssetRegistryV3 registry;QuoteMock quote;
    MockWBNB wrapped;MockRouter router;PredictableFactory dex;
    address constant CREATOR=address(0x123);address constant TREASURY=address(0x777);
    function setUp() public {
        vm.deal(address(this),200 ether);vm.warp(1_000_000);
        wrapped=new MockWBNB();dex=new PredictableFactory();router=new MockRouter(address(wrapped),address(dex));
        LaunchFactory implementation=new LaunchFactory();
        f=LaunchFactoryV5(payable(address(new ERC1967Proxy(address(implementation),abi.encodeCall(implementation.initialize,
            (address(this),TREASURY,address(router),address(new LaunchToken()),address(new DividendVault()),address(new BondingCurve())))))));
        f.upgradeToAndCall(address(new LaunchFactoryV5()),"");
        registry=new QuoteAssetRegistryV3(address(this));quote=new QuoteMock(18);
        PriceMock bnb=new PriceMock();PriceMock stock=new PriceMock();stock.set(140e8,block.timestamp);
        registry.configure(address(0),QuoteAssetRegistry.Asset(address(bnb),0,3600,18,8,0,true));
        registry.configure(address(quote),QuoteAssetRegistry.Asset(address(stock),0,3600,18,8,0,true));
        f.setTemplatesV3(address(registry),address(new LaunchTokenV3()),address(new RevenueVault()),address(new MultiAssetCurve()));
        f.setBNBAdapter(address(new BNBQuoteAdapter(address(wrapped),address(router),address(router))));
        f.setStandaloneDeployers(address(new StandardTokenDeployer(address(f))),address(new StandardCurveDeployer(address(f))),address(new StandaloneVaultDeployer(address(f))));
    }
    function params(address asset,bool taxed) internal view returns(LaunchFactoryV3.CreateParamsV3 memory p){
        p.name="Standard";p.symbol="STD";p.metadataURI="ipfs://test";p.quoteAsset=asset;
        p.expectedConfig=f.launchConfigHash(asset);p.minTarget=registry.quoteLaunch(asset).target;p.maxTarget=p.minTarget;
        p.tax=taxed?LaunchTypes.Tax(300,300,4000,2000,3000,1000,CREATOR,0):LaunchTypes.Tax(0,0,10000,0,0,0,CREATOR,0);
        (address deployer,bytes32 hash)=f.tokenDeploymentConfig();
        for(uint256 i;;i++){
            uint256 free;assembly("memory-safe"){free:=mload(0x40)}
            p.salt=bytes32(i);address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),deployer,keccak256(abi.encode(address(this),p.salt)),hash)))));
            assembly("memory-safe"){mstore(0x40,free)}
            if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0)break;
        }
    }
    function launch(address asset,bool taxed) internal returns(StandardLaunchToken token,StandardCurve c,RevenueVault v){
        token=StandardLaunchToken(f.createTokenV3{value:.01 ether}(params(asset,taxed)));
        (,address pool,address vault,)=f.projects(address(token));c=StandardCurve(pool);v=RevenueVault(payable(vault));
    }
    function testFourInitialPriceAndPointOneBuy() public {
        (StandardLaunchToken t,StandardCurve c,)=launch(address(0),false);
        assertEq(c.graduationTarget(),18 ether);assertEq(t.totalSupply(),1_000_000_000 ether);
        // Official Helper3.calcInitialPrice(18e18,1e27,8e26,0) on BSC, block 120847519.
        assertEq(c.spotPrice(),5_739_795_918);uint256 initial=c.spotPrice();
        assertEq(t.launchPair().code.length,0);assertEq(t.owner(),address(0));
        c.buy{value:.1 ether}(.1 ether,1,block.timestamp,address(this));
        uint256 rise=(c.spotPrice()-initial)*10000/initial;
        assertTrue(rise>320&&rise<325);assertEq(c.progressBps(),t.balanceOf(address(this))*10000/800_000_000 ether);
        assertTrue(c.progressBps()>uint256(.099 ether)*10000/18 ether);
    }
    function testTaxedBuySellAndAutomaticCreatorPayment() public {
        (StandardLaunchToken t,StandardCurve c,RevenueVault v)=launch(address(0),true);
        c.buy{value:.1 ether}(.1 ether,1,block.timestamp,address(this));
        assertEq(c.reserveQuote(),.096 ether);assertEq(CREATOR.balance,.0012 ether);
        assertTrue(v.earned(address(this),address(0))>0);
        uint256 amount=t.balanceOf(address(this));t.approve(address(c),amount);
        (uint256 output,,)=c.quoteSell(amount);assertTrue(output>0);
        c.sell(amount,output,block.timestamp,address(this));
        assertApprox(c.reserveQuote(),0,1);assertApprox(c.spotPrice(),5_739_795_918,1);
    }
    function testGraduationSellsEightHundredMillionAndLocksTwoHundredMillion() public {
        (StandardLaunchToken t,StandardCurve c,)=launch(address(0),false);
        c.buy{value:20 ether}(20 ether,1,block.timestamp,address(this));
        assertEq(c.reserveQuote(),18 ether);assertEq(t.balanceOf(address(this)),800_000_000 ether);assertEq(c.progressBps(),10000);
        uint256 price=c.spotPrice();c.graduate();
        assertTrue(c.graduated());assertEq(t.balanceOf(c.pair()),200_000_000 ether);
        assertEq(wrapped.balanceOf(c.pair()),17.64 ether);assertEq(t.totalBurned(),0);
        assertApprox(price,17.64 ether*1e18/200_000_000 ether,1);
        assertTrue(MockPair(c.pair()).balanceOf(address(0xdead))>0);
        assertEq(c.platformCredit(),.36 ether+uint256(18 ether)/99);
        c.claimPlatform();assertTrue(TREASURY.balance>.36 ether);
    }
    function testPredictedPairCannotReceiveTokensBeforeGraduation() public {
        (StandardLaunchToken t,StandardCurve c,)=launch(address(0),true);
        address p=dex.createPair(address(t),address(wrapped));assertEq(p,t.launchPair());
        vm.expectRevert();c.buy{value:.1 ether}(.1 ether,1,block.timestamp,p);
        assertEq(c.reserveQuote(),0);assertEq(t.balanceOf(p),0);
        c.buy{value:20 ether}(20 ether,1,block.timestamp,address(this));c.graduate();assertEq(c.pair(),p);
    }
    function testBNBBuysStockAtCreationWithoutStockWalletBalance() public {
        address swap=dex.createPair(address(wrapped),address(quote));wrapped.deposit{value:20 ether}();wrapped.transfer(swap,20 ether);quote.mint(swap,100 ether);MockPair(swap).mint(address(this));
        LaunchFactoryV3.CreateParamsV3 memory p=params(address(quote),true);
        LaunchFactoryV3.DeveloperBuy memory b;b.amount=.1 ether;b.minQuote=1;b.minTokens=1;b.deadline=block.timestamp;b.payWithBNB=true;b.route.kind=1;
        b.route.v2Path=new address[](2);b.route.v2Path[0]=address(wrapped);b.route.v2Path[1]=address(quote);
        StandardLaunchToken t=StandardLaunchToken(f.createTokenAndBuyV3{value:.11 ether}(p,b));
        assertTrue(t.balanceOf(address(this))>0);assertEq(quote.balanceOf(address(this)),0);assertEq(quote.balanceOf(address(f)),0);assertEq(t.launchPair().code.length,0);
    }
    function testErc20GraduationAndRoundTrip() public {
        (StandardLaunchToken t,StandardCurve c,)=launch(address(quote),true);
        quote.mint(address(this),200 ether);quote.approve(address(c),type(uint256).max);
        c.buy(1 ether,1,block.timestamp,address(this));t.approve(address(c),type(uint256).max);c.sell(t.balanceOf(address(this)),1,block.timestamp,address(this));
        c.buy(100 ether,1,block.timestamp,address(this));assertEq(c.reserveQuote(),90 ether);c.graduate();
        assertEq(quote.balanceOf(c.pair()),88.2 ether);assertEq(t.balanceOf(c.pair()),200_000_000 ether);
    }
    function testOldLaunchParametersDoNotChangeAfterRegistryReplacement() public {
        (,StandardCurve c,)=launch(address(0),false);uint256 initial=c.virtualQuote();
        QuoteAssetRegistry next=new QuoteAssetRegistry(address(this));f.setTemplatesV3(address(next),f.tokenImplementationV3(),f.vaultImplementationV3(),f.poolImplementationV3());
        assertEq(c.virtualQuote(),initial);assertEq(c.graduationTarget(),18 ether);
        c.buy{value:.1 ether}(.1 ether,1,block.timestamp,address(this));
    }
    function testFuzzRepeatedTradesDoNotChangeSaleCap(uint96 seed) public {
        (StandardLaunchToken t,StandardCurve c,)=launch(address(0),true);
        t.approve(address(c),type(uint256).max);
        for(uint256 i;i<8;i++){
            uint256 amount=(uint256(keccak256(abi.encode(seed,i)))%1e17)+1e12;
            c.buy{value:amount}(amount,1,block.timestamp,address(this));
            if(i%3==2)c.sell(t.balanceOf(address(this))/4,1,block.timestamp,address(this));
            assertTrue(c.progressBps()<10000);assertTrue(c.reserveTokens()>=200_000_000 ether);
        }
        c.buy{value:30 ether}(30 ether,1,block.timestamp,address(this));
        assertEq(t.balanceOf(address(this)),800_000_000 ether);assertEq(c.reserveQuote(),18 ether);
        c.graduate();assertEq(t.balanceOf(c.pair()),200_000_000 ether);
    }
}
