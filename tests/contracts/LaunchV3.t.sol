// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TestBase} from "./TestBase.sol";
import {QuoteMock,PriceMock} from "./QuoteAssets.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaunchFactory} from "../../contracts/src/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/src/LaunchFactoryV3.sol";
import {LaunchToken} from "../../contracts/src/LaunchToken.sol";
import {BondingCurve} from "../../contracts/src/BondingCurve.sol";
import {DividendVault} from "../../contracts/src/DividendVault.sol";
import {QuoteAssetRegistry} from "../../contracts/src/QuoteAssetRegistry.sol";
import {LaunchTypes} from "../../contracts/src/v3/LaunchTypes.sol";
import {LaunchTokenV3} from "../../contracts/src/v3/LaunchTokenV3.sol";
import {MultiAssetCurve} from "../../contracts/src/v3/MultiAssetCurve.sol";
import {RevenueVault} from "../../contracts/src/v3/RevenueVault.sol";
import {BNBQuoteAdapter} from "../../contracts/src/v3/BNBQuoteAdapter.sol";
import {MockWBNB,MockRouter,MockV2Factory,MockPair} from "./Mocks.sol";

contract RejectRecipient {receive()external payable{revert("NO_BNB");}}

abstract contract LaunchV3Fixture is TestBase {
    LaunchFactoryV3 f;
    QuoteAssetRegistry registry;
    QuoteMock quote;
    MockWBNB wrapped;
    MockRouter router;
    BNBQuoteAdapter adapter;
    address constant RECIPIENT=address(0x123);
    address constant TREASURY=address(0x777);
    function setUp() public virtual {
        vm.deal(address(this),100 ether);vm.warp(1_000_000);
        wrapped=new MockWBNB();router=new MockRouter(address(wrapped),address(new MockV2Factory()));
        LaunchFactory implementation=new LaunchFactory();
        LaunchFactory old=LaunchFactory(address(new ERC1967Proxy(address(implementation),abi.encodeCall(implementation.initialize,
            (address(this),TREASURY,address(router),address(new LaunchToken()),address(new DividendVault()),address(new BondingCurve()))))));
        old.upgradeToAndCall(address(new LaunchFactoryV3()),"");f=LaunchFactoryV3(payable(address(old)));
        registry=new QuoteAssetRegistry(address(this));
        PriceMock bnb=new PriceMock();PriceMock stock=new PriceMock();stock.set(140e8,block.timestamp);
        quote=new QuoteMock(18);
        registry.configure(address(0),QuoteAssetRegistry.Asset(address(bnb),0,3600,18,8,0,true));
        registry.configure(address(quote),QuoteAssetRegistry.Asset(address(stock),0,3600,18,8,0,true));
        f.setTemplatesV3(address(registry),address(new LaunchTokenV3()),address(new RevenueVault()),address(new MultiAssetCurve()));
        adapter=new BNBQuoteAdapter(address(wrapped),address(router),address(router));f.setBNBAdapter(address(adapter));
    }
    function _params(address asset,address recipient) internal view virtual returns(LaunchFactoryV3.CreateParamsV3 memory p){
        p.name="Stock Launch";p.symbol="STK";p.metadataURI="ipfs://test";p.quoteAsset=asset;
        p.expectedConfig=f.launchConfigHash(asset);
        uint256 target=registry.quoteLaunch(asset).target;p.minTarget=target;p.maxTarget=target;
        p.tax=LaunchTypes.Tax(200,500,4000,2000,3000,1000,recipient,0);
        address template=f.tokenImplementationV3();
        for(uint256 i;;i++){
            p.salt=bytes32(i);
            uint256 free;assembly("memory-safe"){free:=mload(0x40)}
            address predicted=Clones.predictDeterministicAddress(template,keccak256(abi.encode(address(this),p.salt)),address(f));
            // Vanity mining creates only temporary encodings; reuse that scratch memory in this test helper.
            assembly("memory-safe"){mstore(0x40,free)}
            if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0)break;
        }
    }
}
contract LaunchV3Test is LaunchV3Fixture {
    function _buy(uint256 amount,bool native_) private view returns(LaunchFactoryV3.DeveloperBuy memory b){
        b.amount=amount;b.payWithBNB=native_;b.minQuote=1;b.minTokens=1;b.deadline=block.timestamp;
    }
    function testAtomicNativeCreationBuyFeesAndDividend() public {
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
        address predicted=f.predictTokenV3(address(this),p.salt);
        LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:1.01 ether}(p,_buy(1 ether,true)));
        assertEq(address(token),predicted);assertEq(token.balanceOf(address(this)),_expectedInitialBuy());
        (,address pool,address vault,)=f.projects(address(token));
        assertEq(MultiAssetCurve(pool).reserveQuote(),0.97 ether);
        assertEq(RECIPIENT.balance,0.008 ether);
        assertEq(f.creationCredits(),0.01 ether);assertEq(address(f).balance,0.01 ether);
        assertEq(MultiAssetCurve(pool).platformCredit(),0.01 ether);
        assertEq(RevenueVault(payable(vault)).burnBudget(),0.004 ether);
        uint256 owed=RevenueVault(payable(vault)).earned(address(this),address(0));
        assertApprox(owed,0.006 ether,1);
        RevenueVault(payable(vault)).claim(address(0),address(this));
        assertEq(RevenueVault(payable(vault)).earned(address(this),address(0)),0);
        f.claimCreationFees();assertEq(TREASURY.balance,0.01 ether);
    }
    function _expectedInitialBuy() internal pure virtual returns(uint256){return uint256(1_000_000_000 ether)*97/347;}
    function testAtomicErc20CreatorBuyAndRollbackOnSlippage() public {
        quote.mint(address(this),100 ether);quote.approve(address(f),type(uint256).max);
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(quote),RECIPIENT);
        LaunchFactoryV3.DeveloperBuy memory b=_buy(5 ether,false);b.minTokens=1_000_000_000 ether;
        address predicted=f.predictTokenV3(address(this),p.salt);
        vm.expectRevert();f.createTokenAndBuyV3{value:0.01 ether}(p,b);
        assertEq(predicted.code.length,0);assertEq(f.tokenCount(),0);assertEq(quote.balanceOf(address(this)),100 ether);
        b.minTokens=1;
        f.createTokenAndBuyV3{value:0.01 ether}(p,b);
        assertTrue(LaunchTokenV3(predicted).balanceOf(address(this))>0);
        assertEq(quote.balanceOf(RECIPIENT),0.04 ether);assertEq(quote.balanceOf(address(f)),0);
    }
    function testBNBConvertsAndBuysStockWithZeroStockInCreatorWallet() public {
        address pair=MockV2Factory(router.factory()).createPair(address(wrapped),address(quote));
        wrapped.deposit{value:20 ether}();wrapped.transfer(pair,20 ether);quote.mint(pair,100 ether);MockPair(pair).mint(address(this));
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(quote),RECIPIENT);
        LaunchFactoryV3.DeveloperBuy memory b=_buy(1 ether,true);
        b.route.kind=1;b.route.v2Path=new address[](2);b.route.v2Path[0]=address(wrapped);b.route.v2Path[1]=address(quote);
        b.minQuote=4 ether;uint256 before_=address(this).balance;
        assertEq(quote.balanceOf(address(this)),0);
        LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:1.01 ether}(p,b));
        assertTrue(token.balanceOf(address(this))>0);assertEq(before_-address(this).balance,1.01 ether);
        assertEq(quote.balanceOf(address(this)),0);assertEq(quote.balanceOf(address(f)),0);
        assertEq(quote.balanceOf(address(adapter)),0);assertEq(wrapped.allowance(address(adapter),address(router)),0);
        assertEq(f.creationCredits(),0.01 ether);
    }
    function testNativeOverTargetRefundDoesNotIncludeCreationFee() public {
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
        uint256 before_=address(this).balance;
        LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:20.01 ether}(p,_buy(20 ether,true)));
        (,address pool,,)=f.projects(address(token));
        assertEq(MultiAssetCurve(pool).reserveQuote(),10 ether);assertEq(address(f).balance,0.01 ether);
        assertTrue(before_-address(this).balance<11 ether);
    }
    function testRejectingTaxRecipientCannotBlockBuySellAndDEXTaxPayouts() public {
        RejectRecipient reject=new RejectRecipient();
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),address(reject));
        LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:1.01 ether}(p,_buy(1 ether,true)));
        (,address pool_,address vault_,)=f.projects(address(token));
        MultiAssetCurve pool=MultiAssetCurve(pool_);RevenueVault vault=RevenueVault(payable(vault_));
        assertEq(vault.recipientCredit(address(0)),0.008 ether);
        token.approve(pool_,type(uint256).max);pool.sell(token.balanceOf(address(this))/3,1,block.timestamp,address(this));
        pool.buy{value:20 ether}(20 ether,1,block.timestamp,address(this));pool.graduate();
        address[] memory path=new address[](2);path[0]=address(wrapped);path[1]=address(token);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:0.1 ether}(1,path,address(this),block.timestamp);
        assertTrue(token.balanceOf(address(reject))>0);assertEq(token.balanceOf(address(token)),0);
        assertTrue(vault.totalBuybackBurned()>0);
        path[0]=address(token);path[1]=address(wrapped);token.approve(address(router),type(uint256).max);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(token.balanceOf(address(this))/100,1,path,address(this),block.timestamp);
    }
    function testMinimumHoldingAndPreviouslyEarnedDividends() public {
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);p.tax.minimumHolding=1_000_000 ether;
        LaunchTokenV3 token=LaunchTokenV3(f.createTokenAndBuyV3{value:1.01 ether}(p,_buy(1 ether,true)));
        (,address pool_,address vault_,)=f.projects(address(token));MultiAssetCurve pool=MultiAssetCurve(pool_);RevenueVault vault=RevenueVault(payable(vault_));
        uint256 earnedBefore=vault.earned(address(this),address(0));assertTrue(earnedBefore>0);
        address tiny=address(0x555);pool.buy{value:1e12}(1e12,1,block.timestamp,tiny);
        assertTrue(token.balanceOf(tiny)<p.tax.minimumHolding);assertEq(vault.holderBalance(tiny),0);
        token.approve(pool_,type(uint256).max);pool.sell(token.balanceOf(address(this)),1,block.timestamp,address(this));
        assertEq(vault.holderBalance(address(this)),0);assertTrue(vault.earned(address(this),address(0))>=earnedBefore);
    }
    function testV2MethodsAndOwnershipPreservedAfterUpgrade() public virtual {
        assertEq(f.owner(),address(this));assertEq(f.treasury(),TREASURY);assertEq(f.PROTOCOL_VERSION(),2);
        bytes32 salt;
        for(uint256 i;;i++){
            salt=bytes32(i);if(uint160(f.predictToken(address(this),salt))&0xffff==0x6666)break;
        }
        address token=f.createToken{value:0.01 ether}(LaunchFactory.CreateParams("Legacy","OLD","",salt,f.tokenImplementation(),0,0,0,0,0,0,address(0)));
        (,address pool,,)=f.projects(token);BondingCurve(pool).buy{value:1 ether}(1,block.timestamp,address(this));
        assertEq(BondingCurve(pool).TARGET(),20 ether);assertEq(f.projectVersion(token),0);
        assertTrue(LaunchToken(token).balanceOf(address(this))>0);
    }
    function testExistingV2ProjectBalancesAndCreditsSurviveUpgrade() public {
        LaunchFactory implementation=new LaunchFactory();
        LaunchFactory old=LaunchFactory(address(new ERC1967Proxy(address(implementation),abi.encodeCall(implementation.initialize,
            (address(this),TREASURY,address(router),address(new LaunchToken()),address(new DividendVault()),address(new BondingCurve()))))));
        bytes32 salt;
        for(uint256 i;;i++){salt=bytes32(i);if(uint160(old.predictToken(address(this),salt))&0xffff==0x6666)break;}
        address token=old.createToken{value:0.01 ether}(LaunchFactory.CreateParams("Existing","OLD","",salt,old.tokenImplementation(),100,0,8000,0,1,0,address(0)));
        (,address pool,address vault,uint64 created)=old.projects(token);
        BondingCurve(pool).buy{value:1 ether}(1,block.timestamp,address(this));
        uint256 balance=LaunchToken(token).balanceOf(address(this));
        uint256 rewards=DividendVault(payable(vault)).earned(address(this),address(0));
        address template=old.tokenImplementation();
        old.upgradeToAndCall(address(new LaunchFactoryV3()),"");
        LaunchFactoryV3 upgraded=LaunchFactoryV3(payable(address(old)));
        assertEq(upgraded.owner(),address(this));assertEq(upgraded.treasury(),TREASURY);
        assertEq(upgraded.tokenCount(),1);assertEq(upgraded.creationCredits(),0.01 ether);
        assertEq(upgraded.tokenImplementation(),template);assertEq(LaunchToken(token).balanceOf(address(this)),balance);
        assertEq(DividendVault(payable(vault)).earned(address(this),address(0)),rewards);
        (address creator_,address pool_,address vault_,uint64 created_)=upgraded.projects(token);
        assertEq(creator_,address(this));assertEq(pool_,pool);assertEq(vault_,vault);assertEq(created_,created);
        LaunchToken(token).approve(pool,balance);BondingCurve(pool).sell(balance/2,1,block.timestamp,address(this));
        assertEq(LaunchToken(token).balanceOf(address(this)),balance-balance/2);
        DividendVault(payable(vault)).claim(address(0),address(this));
        assertEq(DividendVault(payable(vault)).earned(address(this),address(0)),0);
        upgraded.claimCreationFees();assertEq(TREASURY.balance,0.01 ether);
    }
}
