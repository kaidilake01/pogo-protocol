// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {TestBase} from "./TestBase.sol";
import {MockAsset} from "./Mocks.sol";
import {FixedAllocationMining} from "../../contracts/src/v13/FixedAllocationMining.sol";

contract FixedAllocationPairMock is MockAsset {
    address public token0;address public token1=address(1);
    constructor(address t){token0=t;}
    function getReserves() external pure returns(uint112,uint112,uint32){return(1000 ether,1 ether,0);}
}
contract FixedAllocationFundingMock {
    MockAsset public token;FixedAllocationMining public mining;FixedAllocationPairMock public pair;
    address public treasury=address(0xfee);
    bool public failing;bool public missingPrice;
    constructor(){token=new MockAsset();pair=new FixedAllocationPairMock(address(token));}
    function initialize() external {require(address(mining)==address(0));mining=new FixedAllocationMining(address(token),address(this),address(this));}
    function start(uint256 budget) external {token.mint(address(this),budget);mining.activate(budget,address(pair));}
    function syncStake(address) external {}
    function stakingPriceUSD() external view returns(uint256){require(!missingPrice);return 1 ether;}
    function setFailing(bool value) external {failing=value;}
    function setMissingPrice(bool value) external {missingPrice=value;}
    function releaseMiningReward(address to,uint256 amount) external {require(msg.sender==address(mining)&&!failing);token.transfer(to,amount);}
}
interface VmFixedAllocationTime { function getBlockTimestamp() external view returns(uint256); }
contract FixedAllocationMiningTest is TestBase {
    function advance(uint256 seconds_) private {vm.warp(VmFixedAllocationTime(address(vm)).getBlockTimestamp()+seconds_);}
    FixedAllocationFundingMock f;FixedAllocationMining m;MockAsset t;FixedAllocationPairMock lp;
    address constant A=address(0xa11ce);address constant B=address(0xb0b);
    uint256 constant BUDGET=180_000_000 ether;
    function setUp() public {
        vm.warp(1_000_000);f=new FixedAllocationFundingMock();f.initialize();f.start(BUDGET);m=f.mining();t=f.token();lp=f.pair();
        for(uint256 i;i<2;i++){address a=i==0?A:B;t.mint(a,10000 ether);lp.mint(a,10000 ether);
            vm.prank(a);t.approve(address(m),type(uint256).max);vm.prank(a);lp.approve(address(m),type(uint256).max);}
    }
    function allStake(address a,uint256 amount) private {vm.prank(a);m.stake(amount,false);vm.prank(a);m.stake(amount,true);vm.prank(a);m.stakeLP(amount);}
    function testRoundingAndAllocationMetadata() public {
        FixedAllocationFundingMock other=new FixedAllocationFundingMock();other.initialize();other.start(101);
        FixedAllocationMining miner=other.mining();
        assertEq(miner.VERSION(),13);assertEq(miner.poolState(0).budget,6);assertEq(miner.poolState(1).budget,31);assertEq(miner.poolState(2).budget,64);
        assertEq(miner.rewardAllocationBps(0),625);assertEq(miner.rewardAllocationBps(1),3125);assertEq(miner.rewardAllocationBps(2),6250);
    }
    function testUnequalStakeDoesNotReallocateBudgets() public {
        vm.prank(A);m.stake(100 ether,false);vm.prank(A);m.stake(500 ether,true);vm.prank(A);m.stakeLP(2000 ether);
        advance(1 days);
        assertEq(m.earnedIn(0,A),125_000 ether);assertEq(m.earnedIn(1,A),625_000 ether);assertEq(m.earnedIn(2,A),1_250_000 ether);
        vm.prank(B);m.stake(900 ether,false);advance(1 days);
        assertEq(m.earnedIn(0,B),112_500 ether);assertEq(m.earnedIn(1,A),1_250_000 ether);assertEq(m.earnedIn(2,A),2_500_000 ether);
    }
    function testSplitAndDayEmissionsNoCrossPoolWeights() public {
        assertEq(m.poolState(0).budget,11_250_000 ether);assertEq(m.poolState(1).budget,56_250_000 ether);assertEq(m.poolState(2).budget,112_500_000 ether);
        allStake(A,100 ether);advance(1 days);
        assertEq(m.earnedIn(0,A),125_000 ether);assertEq(m.earnedIn(1,A),625_000 ether);assertEq(m.earnedIn(2,A),1_250_000 ether);
        assertEq(m.balanceOf(A),200 ether);assertEq(t.balanceOf(address(m)),200 ether);assertEq(lp.balanceOf(address(m)),100 ether);
        uint256 before_=t.balanceOf(A);m.claimFor(A);assertEq(t.balanceOf(A)-before_,2_000_000 ether);
        assertEq(m.claimedRewards(),2_000_000 ether);assertEq(m.participantCount(),1);
    }
    function testIndependentEmptyClocksAndNoRetroactiveJackpot() public {
        advance(100 days);vm.prank(A);m.stake(100 ether,false);
        assertEq(m.earned(A),0);advance(10 days);
        assertEq(m.poolState(0).activeSeconds,10 days);assertEq(m.poolState(1).activeSeconds,0);assertEq(m.poolState(2).activeSeconds,0);
        vm.prank(A);m.withdrawFlexible(100 ether);advance(100 days);
        vm.prank(B);m.stake(100 ether,false);vm.prank(B);m.stakeLP(100 ether);
        assertEq(m.earned(B),0);advance(80 days);m.claimFor(B);
        assertEq(m.poolState(0).claimed,11_250_000 ether);assertEq(m.poolState(2).activeSeconds,80 days);
        assertEq(m.poolState(1).scheduled,0);assertEq(m.poolEndsAt(1),0);
        advance(10 days);m.claimFor(B);assertEq(m.poolState(2).claimed,112_500_000 ether);
        vm.expectRevert(FixedAllocationMining.Inactive.selector);vm.prank(B);m.stakeLP(1);
        vm.prank(B);m.withdrawLP(0,100 ether);vm.prank(B);m.withdrawFlexible(100 ether);
        vm.prank(A);m.stake(100 ether,true);assertEq(m.earnedIn(1,A),0);
        advance(90 days);vm.prank(A);m.withdrawLocked(0,100 ether);
        assertEq(m.claimedRewards(),BUDGET);assertEq(t.balanceOf(address(f)),0);assertEq(t.balanceOf(address(m)),0);assertEq(lp.balanceOf(address(m)),0);
    }
    function testDilutionOnlyAffectsFutureEarnings() public {
        vm.prank(A);m.stakeLP(100 ether);advance(1 days);
        vm.prank(B);m.stakeLP(300 ether);assertEq(m.earnedIn(2,A),1_250_000 ether);assertEq(m.earnedIn(2,B),0);
        advance(1 days);assertEq(m.earnedIn(2,A),1_562_500 ether);assertEq(m.earnedIn(2,B),937_500 ether);
    }
    function testTwentyFourHourIndependentLocksAndPartialExits() public {
        uint256 start=m.startedAt();vm.prank(A);m.stake(500 ether,true);vm.warp(start+12 hours);vm.prank(A);m.stake(200 ether,true);
        vm.warp(start+24 hours-1);vm.expectRevert(FixedAllocationMining.Locked.selector);vm.prank(A);m.withdrawLocked(0,1);
        vm.warp(start+24 hours);vm.prank(A);m.withdrawLocked(0,250 ether);
        assertEq(m.stakeOf(1,A),450 ether);assertEq(m.costUSD(1,A),450 ether);
        vm.expectRevert(FixedAllocationMining.Locked.selector);vm.prank(A);m.withdrawLocked(1,1);
        vm.warp(start+36 hours);vm.prank(A);m.withdrawLocked(0,250 ether);vm.prank(A);m.withdrawLocked(1,200 ether);
        assertEq(m.balanceOf(A),0);assertEq(m.costUSD(1,A),0);
    }
    function testRewardFailureCannotBlockPrincipalInAnyPool() public {
        allStake(A,100 ether);advance(1 days);f.setFailing(true);
        uint256 before_=t.balanceOf(A);vm.prank(A);m.withdrawFlexible(100 ether);vm.prank(A);m.withdrawLocked(0,100 ether);vm.prank(A);m.withdrawLP(0,100 ether);
        assertEq(t.balanceOf(A)-before_,200 ether);assertEq(lp.balanceOf(A),10000 ether);assertEq(m.earned(A),2_000_000 ether);
        f.setFailing(false);m.claimFor(A);assertEq(m.earned(A),0);assertEq(m.claimedRewards(),2_000_000 ether);
    }
    function testMissingPricesNeverGateStakeOrWithdraw() public {
        f.setMissingPrice(true);allStake(A,100 ether);assertEq(m.unpriced(0,A),100 ether);assertEq(m.unpriced(2,A),100 ether);
        advance(1 days);vm.prank(A);m.withdrawFlexible(100 ether);vm.prank(A);m.withdrawLocked(0,100 ether);vm.prank(A);m.withdrawLP(0,100 ether);
        for(uint8 i;i<3;i++){assertEq(m.unpriced(i,A),0);assertEq(m.costUSD(i,A),0);}
    }
    function testOnlyCanonicalLPAndNoUnapprovedWithdrawOrActivation() public {
        MockAsset fake=new MockAsset();fake.mint(A,100 ether);vm.prank(A);fake.transfer(address(m),100 ether);
        assertEq(m.stakeOf(2,A),0);assertEq(m.lpToken(),address(lp));
        vm.expectRevert(FixedAllocationMining.Unauthorized.selector);m.activate(100,address(fake));
        vm.expectRevert(FixedAllocationMining.Unauthorized.selector);m.payReward(A);
        vm.expectRevert(FixedAllocationMining.InvalidConfig.selector);f.start(100);
        vm.expectRevert(FixedAllocationMining.InvalidAmount.selector);vm.prank(B);m.withdrawLP(0,1);
        vm.expectRevert(FixedAllocationMining.InvalidConfig.selector);m.poolState(3);
    }
    function testEarlyExitPenaltyForSingleAndLPIsPermanentlyLocked() public {
        allStake(A,100 ether);advance(12 hours);
        vm.expectRevert(FixedAllocationMining.Locked.selector);vm.prank(A);m.withdrawLP(0,10 ether);
        uint256 tokenBefore=t.balanceOf(A);uint256 lpBefore=lp.balanceOf(A);f.setFailing(true);
        vm.prank(A);m.withdrawLockedEarly(0,40 ether);vm.prank(A);m.withdrawLPEarly(0,40 ether);
        assertEq(t.balanceOf(A)-tokenBefore,36 ether);assertEq(lp.balanceOf(A)-lpBefore,36 ether);
        assertEq(t.balanceOf(address(0xdead)),4 ether);assertEq(lp.balanceOf(address(0xdead)),4 ether);
        assertEq(m.stakeOf(1,A),60 ether);assertEq(m.stakeOf(2,A),60 ether);
        assertEq(m.costUSD(1,A),60 ether);assertTrue(m.earned(A)>0);
        advance(12 hours);vm.prank(A);m.withdrawLockedEarly(0,60 ether);vm.prank(A);m.withdrawLPEarly(0,60 ether);
        assertEq(t.balanceOf(address(0xdead)),4 ether);assertEq(lp.balanceOf(address(0xdead)),4 ether);
        vm.prank(A);m.withdrawFlexible(100 ether);assertEq(t.balanceOf(address(m)),0);assertEq(lp.balanceOf(address(m)),0);
        f.setFailing(false);m.claimFor(A);assertEq(m.earned(A),0);
    }
    function testLPAdditionalDepositDoesNotExtendOldLock() public {
        vm.prank(A);m.stakeLP(100 ether);advance(12 hours);vm.prank(A);m.stakeLP(100 ether);
        advance(12 hours);vm.prank(A);m.withdrawLP(0,100 ether);
        vm.expectRevert(FixedAllocationMining.Locked.selector);vm.prank(A);m.withdrawLP(1,100 ether);
        advance(12 hours);vm.prank(A);m.withdrawLP(1,100 ether);assertEq(m.stakeOf(2,A),0);
        assertEq(lp.balanceOf(address(0xdead)),0);
    }
    function testFuzzConservationAndNoEmissionBeyondBudget(uint96 seed) public {
        uint256 a=uint256(seed)%4000 ether+1 ether;uint256 b=uint256(keccak256(abi.encode(seed)))%4000 ether+1 ether;
        allStake(A,a);advance(1 days);allStake(B,b);
        advance(19 days);vm.prank(A);m.withdrawFlexible(a/2);vm.prank(B);m.withdrawLP(0,b/2);
        advance(100 days);m.claimFor(A);m.claimFor(B);
        for(uint8 i;i<3;i++){assertLe(m.poolState(i).claimed,m.poolState(i).budget);assertEq(m.poolState(i).activeSeconds,90 days);}
        assertLe(m.claimedRewards(),BUDGET);assertApprox(m.claimedRewards(),BUDGET,1000);
        vm.prank(A);m.withdrawFlexible(a-a/2);vm.prank(A);m.withdrawLocked(0,a);vm.prank(A);m.withdrawLP(0,a);
        vm.prank(B);m.withdrawFlexible(b);vm.prank(B);m.withdrawLocked(0,b);vm.prank(B);m.withdrawLP(0,b-b/2);
        assertEq(t.balanceOf(address(m)),0);assertEq(lp.balanceOf(address(m)),0);
    }
}
