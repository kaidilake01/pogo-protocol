// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchV3Fixture} from "./LaunchV3.t.sol";
import {BNBTradeRouter} from "../../contracts/src/v3/BNBTradeRouter.sol";
import {BNBQuoteAdapter} from "../../contracts/src/v3/BNBQuoteAdapter.sol";
import {LaunchTokenV3} from "../../contracts/src/v3/LaunchTokenV3.sol";
import {MultiAssetCurve} from "../../contracts/src/v3/MultiAssetCurve.sol";
import {MockV2Factory,MockPair} from "./Mocks.sol";

contract BNBTradingTest is LaunchV3Fixture {
    BNBTradeRouter trading;
    function setUp() public override {
        super.setUp();trading=new BNBTradeRouter(address(f),address(adapter));
        address pair=MockV2Factory(router.factory()).createPair(address(wrapped),address(quote));
        wrapped.deposit{value:20 ether}();wrapped.transfer(pair,20 ether);quote.mint(pair,100 ether);MockPair(pair).mint(address(this));
    }
    function _route(bool buy) internal view returns(BNBQuoteAdapter.Route memory r){
        r.kind=1;r.v2Path=new address[](2);
        r.v2Path[0]=buy?address(wrapped):address(quote);r.v2Path[1]=buy?address(quote):address(wrapped);
    }
    function _project(bool modern) internal returns(LaunchTokenV3 token,MultiAssetCurve pool){
        if(modern)f.setTradeRouterV3(address(trading));
        token=LaunchTokenV3(f.createTokenV3{value:0.01 ether}(_params(address(quote),RECIPIENT)));
        (,address p,,)=f.projects(address(token));pool=MultiAssetCurve(p);
    }
    function testBNBTradingRoundTripWithoutHoldingQuote() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        assertTrue(bought>0);assertEq(quote.balanceOf(address(this)),0);
        token.approve(address(pool),bought);uint256 before_=address(this).balance;
        uint256 out=trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        assertEq(address(this).balance-before_,out);assertTrue(out>0);assertEq(token.balanceOf(address(this)),0);
        assertEq(quote.balanceOf(address(this)),0);assertEq(quote.balanceOf(address(trading)),0);
        assertEq(wrapped.balanceOf(address(trading)),0);assertEq(quote.allowance(address(trading),address(router)),0);
        assertEq(token.allowance(address(this),address(pool)),0);
    }
    function testBNBTradingBadRouteOrMinOutputRollsBackEntireBuyAndSell() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        uint256 before_=address(this).balance;
        vm.expectRevert();trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(false));
        assertEq(address(this).balance,before_);assertEq(pool.reserveQuote(),0);
        vm.expectRevert();trading.buyWithBNB{value:0.1 ether}(address(token),1,1_000_000_000 ether,block.timestamp,_route(true));
        assertEq(address(this).balance,before_);assertEq(pool.reserveQuote(),0);
        uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        token.approve(address(pool),bought);uint256 reserve=pool.reserveQuote();
        vm.expectRevert();trading.sellToBNB(address(token),bought,1,100 ether,block.timestamp,_route(false));
        assertEq(token.balanceOf(address(this)),bought);assertEq(pool.reserveQuote(),reserve);
        vm.expectRevert();trading.sellToBNB(address(token),bought,1,1,block.timestamp-1,_route(false));
    }
    function testBNBTradingCannotUseAnotherUsersPoolApproval() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        token.approve(address(pool),bought);
        vm.prank(address(0xbad));vm.expectRevert();pool.sellFor(address(this),bought,1,block.timestamp,address(0xbad));
        vm.prank(address(0xbad));vm.expectRevert();trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        assertEq(token.balanceOf(address(this)),bought);
        vm.expectRevert();pool.setTradeRouter(address(adapter));
    }
    function testBNBTradingKeepsDonationsAndRefundsOnlyCurrentCall() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        quote.mint(address(trading),3 ether);wrapped.deposit{value:0.01 ether}();wrapped.transfer(address(trading),0.01 ether);
        uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        token.approve(address(pool),bought);
        trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        assertEq(quote.balanceOf(address(trading)),3 ether);assertEq(wrapped.balanceOf(address(trading)),0.01 ether);
    }
    function testBNBTradingLegacySellHasExplicitFollowupConversion() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(false);
        uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        token.approve(address(pool),bought);
        vm.expectRevert(BNBTradeRouter.LegacyCurve.selector);trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        pool.sell(bought,1,block.timestamp,address(this));uint256 proceeds=quote.balanceOf(address(this));
        quote.approve(address(trading),proceeds);uint256 before_=address(this).balance;
        trading.convertQuoteToBNB(address(quote),proceeds,1,block.timestamp,_route(false));
        assertTrue(address(this).balance>before_);assertEq(quote.balanceOf(address(this)),0);
    }
    function testBNBTradingGraduatedTaxedTokenBothDirections() public {
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        quote.mint(address(this),200 ether);quote.approve(address(pool),200 ether);pool.buy(200 ether,1,block.timestamp,address(this));pool.graduate();
        uint256 quoteBefore=quote.balanceOf(address(this));uint256 bought=trading.buyWithBNB{value:0.1 ether}(address(token),1,1,block.timestamp,_route(true));
        assertTrue(bought>0);token.approve(address(trading),bought);
        uint256 before_=address(this).balance;trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        assertTrue(address(this).balance>before_);assertEq(quote.balanceOf(address(this)),quoteBefore);
        assertEq(token.balanceOf(address(trading)),0);assertEq(quote.balanceOf(address(trading)),0);
    }
    function testFuzzBNBTradingRoundtripConservesRouterBalances(uint96 raw) public {
        uint256 input=0.001 ether+uint256(raw)%1 ether;
        (LaunchTokenV3 token,MultiAssetCurve pool)=_project(true);
        uint256 bought=trading.buyWithBNB{value:input}(address(token),1,1,block.timestamp,_route(true));
        token.approve(address(pool),bought);uint256 out=trading.sellToBNB(address(token),bought,1,1,block.timestamp,_route(false));
        assertLe(out,input);assertEq(quote.balanceOf(address(trading)),0);assertEq(wrapped.balanceOf(address(trading)),0);assertEq(address(trading).balance,0);
    }
}
