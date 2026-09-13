// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {CurrentLaunchFixture} from "./CurrentLaunchFixture.sol";
import {DeferredMiningRevenueVault as QuoteRevenueVault} from "../../contracts/src/MiningRevenueVault.sol";
import {LaunchFactoryV8} from "../../contracts/src/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {DeferredMiningCurve as MiningCurve} from "../../contracts/src/MiningCurve.sol";
import {FixedAllocationMining as LaunchMining} from "../../contracts/src/Mining.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";
import {QuoteMock,PriceMock} from "./QuoteMocks.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockPair} from "./Mocks.sol";
interface VmQuoteRevenue {function mockCallRevert(address,bytes calldata,bytes calldata) external;function clearMockedCalls() external;function etch(address,bytes calldata) external;}
contract RejectQuoteRecipient {receive() external payable {revert();}}

contract QuoteRevenueTest is CurrentLaunchFixture {
    function makeQuoteLaunch(bool stable) internal returns(StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,address asset){
        if(stable){
            QuoteMock q=new QuoteMock(6);PriceMock price=new PriceMock();price.set(1e8,block.timestamp);
            registry.configure(address(q),QuoteAssetRegistry.Asset(address(price),0,3600,6,8,0,true));asset=address(q);
        }
        LaunchFactoryV8 next=f;
        LaunchFactoryV3.CreateParamsV3 memory p=params(asset,true);
        p.minTarget=QuoteAssetRegistry(address(next.quoteRegistry())).quoteLaunch(asset).target;p.maxTarget=p.minTarget;
        p.expectedConfig=next.templateConfigHash(asset,13);
        p.tax=LaunchTypes.Tax(300,300,3000,0,7000,0,address(0x777),0);
        t=StandardLaunchToken(next.createTokenWithTemplateV8(p,13));(,address pool,address vault,)=next.projects(address(t));
        c=MiningCurve(pool);v=QuoteRevenueVault(payable(vault));
        if(stable){QuoteMock(asset).mint(address(this),100_000e6);IERC20(asset).approve(pool,type(uint256).max);c.buy(100_000e6,1,block.timestamp,address(this));}
        else c.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));
        assertTrue(v.earned(address(this),asset)>0);assertEq(v.earned(address(this),address(t)),0);
        c.graduate();
    }
    function sellTax(StandardLaunchToken t,MiningCurve c,address asset) internal {
        address[] memory path=new address[](2);path[0]=address(t);path[1]=asset==address(0)?address(wrapped):asset;
        t.approve(address(router),type(uint256).max);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(t.balanceOf(address(this))/100,1,path,address(this),block.timestamp);
        assertTrue(c.graduated());
    }
    function testQuoteOnlyNativeAndTokenClaimRejected() public { exerciseQuote(false); }
    function testQuoteOnlySixDecimalAssetAndTokenClaimRejected() public { exerciseQuote(true); }
    function exerciseQuote(bool stable) internal {
        (StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,address asset)=makeQuoteLaunch(stable);
        sellTax(t,c,asset);
        assertTrue(v.pendingTokenRevenue()>0);assertEq(v.earned(address(this),address(t)),0);
        assertEq(v.recipientCredit(address(t)),0);assertEq(v.totalDistributed(address(t)),0);
        assertTrue(v.validAsset(asset));assertTrue(!v.validAsset(address(t)));
        vm.expectRevert(QuoteRevenueVault.InvalidConfig.selector);v.claim(address(t),address(this));
        uint256 before_=v.earned(address(this),asset);uint256 pending=v.pendingTokenRevenue();
        assertEq(v.runAutomation(),4);assertEq(v.runAutomation(),0);vm.warp(block.timestamp+180);
        assertEq(v.runAutomation(),12);assertTrue(v.pendingTokenRevenue()<pending);
        assertTrue(v.earned(address(this),asset)>before_);assertEq(v.earned(address(this),address(t)),0);
        assertTrue(v.totalQuoteRevenueConverted()>0);assertTrue(v.totalTokenRevenueConverted()>0);
        uint256 earned=v.earned(address(this),asset);uint256 balance=asset==address(0)?address(this).balance:IERC20(asset).balanceOf(address(this));
        v.claim(asset,address(this));assertEq(v.earned(address(this),asset),0);
        assertEq((asset==address(0)?address(this).balance:IERC20(asset).balanceOf(address(this)))-balance,earned);
    }
    function testQuoteOnlyManipulatedPriceRetainsUnconvertedTaxes() public {
        (StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,)=makeQuoteLaunch(false);sellTax(t,c,address(0));
        assertEq(v.runAutomation(),4);vm.warp(block.timestamp+180);
        wrapped.deposit{value:1 ether}();wrapped.transfer(c.pair(),1 ether);MockPair(c.pair()).sync();
        uint256 pending=v.pendingTokenRevenue();uint256 earned=v.earned(address(this),address(0));
        assertEq(v.runAutomation(),4);assertEq(v.pendingTokenRevenue(),pending);assertEq(v.earned(address(this),address(0)),earned);
    }
    function testQuoteOnlyStakingPrincipalRetainsEligibility() public {
        (StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,)=makeQuoteLaunch(false);
        LaunchMining m=LaunchMining(c.stakingPool());uint256 eligible=v.eligibleSupply();
        t.approve(address(m),type(uint256).max);m.stake(100_000 ether,true);
        assertEq(v.eligibleSupply(),eligible);assertEq(v.holderBalance(address(this)),t.balanceOf(address(this))+m.balanceOf(address(this)));
        assertEq(v.holderBalance(address(m)),0);
    }
    function testQuoteOnlyRejectsUnauthorizedRevenue() public {
        (, ,QuoteRevenueVault v,)=makeQuoteLaunch(false);
        vm.expectRevert(QuoteRevenueVault.Unauthorized.selector);v.depositTokenRevenue(1);
        vm.expectRevert(QuoteRevenueVault.Unauthorized.selector);v.notifyQuote{value:1}(1);
    }
    function testOptionalBudgetFailureCannotUndoQuoteDividends() public {
        (StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,)=makeQuoteLaunch(false);sellTax(t,c,address(0));
        v.runAutomation();vm.warp(block.timestamp+180);
        uint256 pending=v.pendingTokenRevenue();uint256 earned=v.earned(address(this),address(0));
        VmQuoteRevenue(address(vm)).mockCallRevert(address(v),abi.encodeWithSelector(v.processBudgets.selector),abi.encodeWithSignature('Error(string)','LP unavailable'));
        assertEq(v.runAutomation(),12);assertTrue(v.pendingTokenRevenue()<pending);
        assertTrue(v.earned(address(this),address(0))>earned);assertTrue(v.totalQuoteRevenueConverted()>0);
        VmQuoteRevenue(address(vm)).clearMockedCalls();
    }
    function testRejectingRecipientRetainsQuoteCreditWithoutBlockingSell() public {
        (StandardLaunchToken t,MiningCurve c,QuoteRevenueVault v,)=makeQuoteLaunch(false);
        RejectQuoteRecipient rejected=new RejectQuoteRecipient();VmQuoteRevenue(address(vm)).etch(address(0x777),address(rejected).code);
        sellTax(t,c,address(0));v.runAutomation();vm.warp(block.timestamp+180);v.runAutomation();
        uint256 credit=v.recipientCredit(address(0));assertTrue(credit>0);assertEq(v.recipientCredit(address(t)),0);
        v.flushRecipient(address(0));assertEq(v.recipientCredit(address(0)),credit);
        VmQuoteRevenue(address(vm)).etch(address(0x777),'');uint256 before_=address(0x777).balance;
        v.flushRecipient(address(0));assertEq(address(0x777).balance-before_,credit);assertEq(v.recipientCredit(address(0)),0);
    }
    function testPermissionlessClaimOnlyPaysBeneficiary() public {
        (, ,QuoteRevenueVault v,)=makeQuoteLaunch(false);uint256 reward=v.earned(address(this),address(0));uint256 before_=address(this).balance;
        vm.prank(address(0x555));v.claimFor(address(this));assertEq(address(this).balance-before_,reward);assertEq(v.earned(address(this),address(0)),0);
        vm.prank(address(0x555));vm.expectRevert(QuoteRevenueVault.InvalidAmount.selector);v.claimFor(address(this));
        vm.expectRevert(QuoteRevenueVault.Unauthorized.selector);v.processBudgets(1);
    }
}
