// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaunchFactory} from "../../contracts/src/LaunchFactory.sol";
import {LaunchToken} from "../../contracts/src/LaunchToken.sol";
import {BondingCurve} from "../../contracts/src/BondingCurve.sol";
import {DividendVault} from "../../contracts/src/DividendVault.sol";
import {TestBase} from "./TestBase.sol";
import {MockAsset, MockWBNB, MockPair, MockV2Factory, MockRouter} from "./Mocks.sol";

contract FactoryV2TestImplementation is LaunchFactory {
    function version() external pure returns (uint256) {
        return 2;
    }
}

contract RejectBNB {
    receive() external payable {
        revert("REJECT");
    }
}

contract ReenterClaim {
    DividendVault public vault;
    bool public attempted;

    constructor(DividendVault v) {
        vault = v;
    }

    receive() external payable {
        attempted = true;
        (bool ok,) = address(vault).call(abi.encodeCall(vault.claim, (address(0), address(this))));
        require(!ok, "REENTRANCY_SUCCEEDED");
    }
}

contract LaunchpadTest is TestBase {
    LaunchFactory internal factory;
    LaunchToken internal token;
    BondingCurve internal pool;
    DividendVault internal vault;
    MockRouter internal router;
    MockWBNB internal wbnb;
    MockV2Factory internal dexFactory;
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    address internal treasury = address(0x777);
    uint256 internal serial;

    function setUp() public virtual {
        vm.warp(1_800_000_000);
        vm.deal(address(this), 1000 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        wbnb = new MockWBNB();
        dexFactory = new MockV2Factory();
        router = new MockRouter(address(wbnb), address(dexFactory));
        LaunchFactory impl = new LaunchFactory();
        factory = LaunchFactory(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeCall(
                        impl.initialize,
                        (
                            address(this),
                            treasury,
                            address(router),
                            address(new LaunchToken()),
                            address(new DividendVault()),
                            address(new BondingCurve())
                        )
                    )
                )
            )
        );
        _create(300, 100, 8000, 0, address(0));
    }

    function _salt(address creator) internal view returns (bytes32 salt) {
        bytes32 codeHash = keccak256(
            abi.encodePacked(
                hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
                factory.tokenImplementation(),
                hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
        address factory_ = address(factory);
        for (uint256 i;; ++i) {
            address predicted;
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                mstore(ptr, creator)
                mstore(add(ptr, 32), i)
                let effective := keccak256(ptr, 64)
                mstore(ptr, shl(248, 0xff))
                mstore(add(ptr, 1), shl(96, factory_))
                mstore(add(ptr, 21), effective)
                mstore(add(ptr, 53), codeHash)
                predicted := and(keccak256(ptr, 85), 0xffffffffffffffffffffffffffffffffffffffff)
            }
            if (uint160(predicted) & 0xffff == 0x6666 && predicted.code.length == 0) return bytes32(i);
        }
    }

    function _params(address creator) internal view returns (LaunchFactory.CreateParams memory p) {
        p = LaunchFactory.CreateParams(
            "EMBER TEST",
            "TEST",
            "https://example.org/test.json",
            _salt(creator),
            factory.tokenImplementation(),
            300,
            100,
            8000,
            0,
            1,
            1,
            address(0)
        );
    }

    function _create(uint16 tax, uint16 burn, uint16 share, uint16 buyback_, address extra) internal {
        LaunchFactory.CreateParams memory p = _params(alice);
        p.revenueBps = tax;
        p.burnBps = burn;
        p.holderShareBps = share;
        p.buybackShareBps = buyback_;
        p.rewardMode = share > 0 ? 1 : 0;
        p.burnMode = buyback_ > 0 ? (burn > 0 ? 3 : 2) : (burn > 0 ? 1 : 0);
        p.extraRewardAsset = extra;
        vm.prank(alice);
        token = LaunchToken(factory.createToken{value: 0.01 ether}(p));
        (, address pool_, address vault_,) = factory.projects(address(token));
        pool = BondingCurve(pool_);
        vault = DividendVault(payable(vault_));
    }

    function _buy(address who, uint256 value) internal returns (uint256 out) {
        uint256 before_ = token.balanceOf(who);
        vm.prank(who);
        pool.buy{value: value}(0, block.timestamp + 100, who);
        return token.balanceOf(who) - before_;
    }

    function _sell(address who, uint256 value) internal {
        vm.startPrank(who);
        token.approve(address(pool), value);
        pool.sell(value, 0, block.timestamp + 100, who);
        vm.stopPrank();
    }

    function _govern(address target, bytes memory data) internal {
        uint256 beforeTimestamp = block.timestamp;
        (bool success, bytes memory reason) = target.call(data);
        if (!success) assembly { revert(add(reason, 32), mload(reason)) }
        assertEq(block.timestamp, beforeTimestamp);
    }

    function testFixedSupplyVanityAndCreationFees() public view {
        assertEq(token.totalSupply(), 1_000_000_000 ether);
        assertEq(token.balanceOf(address(pool)), token.totalSupply());
        assertEq(uint160(address(token)) & 0xffff, 0x6666);
        assertEq(factory.tokenCount(), 1);
        assertEq(factory.creationCredits(), 0.01 ether);
        assertEq(factory.owner(), address(this));
    }

    function testCreatorSaltCannotBeFrontRun() public view {
        bytes32 salt = _salt(alice);
        assertTrue(factory.predictToken(alice, salt) != factory.predictToken(bob, salt));
    }

    function testIncorrectSuffixRejected() public {
        LaunchFactory.CreateParams memory p = _params(alice);
        for (uint256 i;; i++) {
            p.salt = bytes32(i);
            if (uint160(factory.predictToken(alice, p.salt)) & 0xffff != 0x6666) break;
        }
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidSuffix.selector);
        factory.createToken{value: 0.01 ether}(p);
    }

    function testStaleTemplateIsRejected() public {
        LaunchFactory.CreateParams memory p = _params(alice);
        p.expectedImplementation = address(0x123);
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
    }

    function testNoMintOrUserFundRescue() public {
        (bool mint,) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", alice, 1 ether));
        assertTrue(!mint);
        (bool rescue,) =
            address(vault).call(abi.encodeWithSignature("rescue(address,uint256)", alice, 1 ether));
        assertTrue(!rescue);
    }

    function testBuyQuoteTaxBurnAndExactReserves() public {
        (uint256 out, uint256 used,, uint256 fee, uint256 revenue, uint256 burned) = pool.quoteBuy(1 ether);
        assertEq(_buy(alice, 1 ether), out);
        assertEq(pool.reserveBNB(), used - fee - revenue);
        assertEq(address(pool).balance, pool.reserveBNB() + pool.platformCredit());
        assertEq(address(vault).balance, revenue);
        assertEq(token.totalBurned(), burned);
        assertEq(token.totalSupply() + token.totalBurned(), token.INITIAL_SUPPLY());
        assertEq(vault.creatorCredit(address(0)), revenue * 2000 / 10000);
    }

    function testSellQuoteAndRoundTripLosesFees() public {
        uint256 starting = alice.balance;
        uint256 out = _buy(alice, 1 ether);
        (uint256 received,,, uint256 burned) = pool.quoteSell(out);
        uint256 before_ = alice.balance;
        _sell(alice, out);
        assertEq(alice.balance - before_, received);
        assertTrue(alice.balance < starting);
        assertEq(token.balanceOf(alice), 0);
        assertGe(token.totalBurned(), burned);
        assertEq(address(pool).balance, pool.reserveBNB() + pool.platformCredit());
    }

    function testSlippageAndExpiryNeverMoveFunds() public {
        vm.prank(alice);
        vm.expectRevert(BondingCurve.Slippage.selector);
        pool.buy{value: 1 ether}(1_000_000_000 ether, block.timestamp, alice);
        vm.prank(alice);
        vm.expectRevert(BondingCurve.Deadline.selector);
        pool.buy{value: 1 ether}(0, block.timestamp - 1, alice);
        assertEq(pool.reserveBNB(), 0);
        assertEq(token.balanceOf(alice), 0);
    }

    function testOverfundingRefundsOnlyExcess() public {
        (, uint256 used, uint256 refund,,,) = pool.quoteBuy(50 ether);
        uint256 start = alice.balance;
        _buy(alice, 50 ether);
        assertEq(pool.reserveBNB(), 20 ether);
        assertEq(start - alice.balance, used);
        assertEq(used + refund, 50 ether);
    }

    function testAtTargetBuyStopsSellStillWorks() public {
        _buy(alice, 30 ether);
        vm.prank(bob);
        vm.expectRevert(BondingCurve.Graduated.selector);
        pool.buy{value: 1 ether}(0, block.timestamp, bob);
        _sell(alice, token.balanceOf(alice) / 20);
        assertTrue(pool.reserveBNB() < 20 ether);
        _buy(bob, 1 ether);
    }

    function testGraduationIsPermissionlessAndLPBurned() public {
        _buy(alice, 30 ether);
        vm.prank(bob);
        pool.graduate();
        MockPair pair = MockPair(pool.pair());
        assertTrue(pool.graduated());
        assertEq(token.pair(), address(pair));
        assertEq(pair.balanceOf(address(0xdead)), pair.totalSupply());
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(address(pool).balance, pool.platformCredit());
        assertEq(token.totalSupply() + token.totalBurned(), token.INITIAL_SUPPLY());
        vm.expectRevert(BondingCurve.Graduated.selector);
        pool.graduate();
    }

    function testGraduationBeforeTargetFails() public {
        vm.expectRevert(BondingCurve.NotReady.selector);
        pool.graduate();
    }

    function testWBNBPreseedSyncCannotBlockGraduation() public {
        _buy(alice, 30 ether);
        address pair = dexFactory.getPair(address(token), address(wbnb));
        wbnb.deposit{value: 1 ether}();
        wbnb.transfer(pair, 1 ether);
        MockPair(pair).sync();
        pool.graduate();
        assertTrue(pool.graduated());
    }

    function testPostGraduationTaxAndPublicDistribution() public {
        _buy(alice, 30 ether);
        pool.graduate();
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(token);
        vm.prank(bob);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(
            1, path, bob, block.timestamp
        );
        uint256 fees = token.balanceOf(address(token));
        assertTrue(fees > 0);
        vm.prank(bob);
        token.distributeFees();
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(vault.creatorCredit(address(token)), fees - fees * 8000 / 10000);
        assertEq(token.balanceOf(address(vault)), fees);
        path[0] = address(token);
        path[1] = address(wbnb);
        uint256 before_ = bob.balance;
        vm.startPrank(bob);
        token.approve(address(router), type(uint256).max);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            token.balanceOf(bob), 1, path, bob, block.timestamp
        );
        vm.stopPrank();
        assertTrue(bob.balance > before_);
    }

    function testFeeClaimsGoOnlyToTreasury() public {
        _buy(alice, 1 ether);
        uint256 credit = pool.platformCredit();
        vm.prank(bob);
        pool.claimPlatform();
        assertEq(treasury.balance, credit);
        vm.prank(bob);
        factory.claimCreationFees();
        assertEq(treasury.balance, credit + 0.01 ether);
    }

    function testUnapprovedExtraAssetRejected() public {
        LaunchFactory.CreateParams memory p = _params(alice);
        p.extraRewardAsset = address(new MockAsset());
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
    }

    function testOnlyCreatorCanClaimItsCredit() public {
        _buy(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert(DividendVault.Unauthorized.selector);
        vault.claimCreator(address(0), bob);
        uint256 credit = vault.creatorCredit(address(0));
        uint256 start = alice.balance;
        vm.prank(alice);
        vault.claimCreator(address(0), alice);
        assertEq(alice.balance - start, credit);
    }

    function testPauseNewCreationDoesNotPauseExistingExit() public {
        _buy(alice, 1 ether);
        _govern(address(factory), abi.encodeCall(factory.setCreationPaused, (true)));
        LaunchFactory.CreateParams memory p = _params(alice);
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.CreationPaused.selector);
        factory.createToken{value: 0.01 ether}(p);
        _sell(alice, token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 0);
    }

    function testOwnerUpgradeIsImmediateAndPreservesState() public {
        FactoryV2TestImplementation next = new FactoryV2TestImplementation();
        vm.prank(bob);
        vm.expectRevert();
        factory.upgradeToAndCall(address(next), "");
        address oldTokenImpl = factory.tokenImplementation();
        uint256 beforeTimestamp = block.timestamp;
        factory.upgradeToAndCall(address(next), "");
        assertEq(block.timestamp, beforeTimestamp);
        assertEq(FactoryV2TestImplementation(address(factory)).version(), 2);
        assertEq(factory.tokenCount(), 1);
        assertEq(factory.tokenImplementation(), oldTokenImpl);
        assertEq(factory.creationCredits(), 0.01 ether);
        assertEq(token.revenueBps(), 300);
        _buy(alice, 1 ether);
        _sell(alice, token.balanceOf(alice));
    }

    function testTemplateChangesDoNotChangeExistingClones() public {
        address previous = factory.tokenImplementation();
        _govern(
            address(factory),
            abi.encodeCall(
                factory.setTemplates,
                (address(new LaunchToken()), address(new DividendVault()), address(new BondingCurve()))
            )
        );
        assertTrue(factory.tokenImplementation() != previous);
        assertEq(factory.templateVersion(), 2);
        assertEq(token.revenueBps(), 300);
        assertEq(token.burnBps(), 100);
        _buy(bob, 1 ether);
    }

    function testEOAOwnerControlsImmediatelyAndOwnershipNeedsAcceptance() public {
        factory.transferOwnership(bob);
        assertEq(factory.owner(), address(this));
        assertEq(factory.pendingOwner(), bob);
        vm.prank(alice);
        vm.expectRevert();
        factory.acceptOwnership();
        vm.prank(bob);
        factory.acceptOwnership();
        assertEq(factory.owner(), bob);
        vm.prank(bob);
        factory.setCreationPaused(true);
        assertTrue(factory.creationPaused());
        vm.expectRevert();
        factory.setCreationPaused(false);
        vm.prank(bob);
        factory.setCreationPaused(false);
        assertTrue(!factory.creationPaused());
    }

    function testOnlyOwnerCanChangeTemplatesAndAssetList() public {
        address impl = factory.tokenImplementation();
        address v = factory.vaultImplementation();
        address p = factory.poolImplementation();
        vm.prank(bob);
        vm.expectRevert();
        factory.setTemplates(impl, v, p);
        MockAsset asset = new MockAsset();
        vm.prank(bob);
        vm.expectRevert();
        factory.setRewardAsset(address(asset), true);
        factory.setRewardAsset(address(asset), true);
        assertTrue(factory.allowedRewardAssets(address(asset)));
        factory.setRewardAsset(address(asset), false);
        assertTrue(!factory.allowedRewardAssets(address(asset)));
    }

    function testFuzz_RoundTripCannotProfit(uint128 input) public {
        uint256 value = uint256(input) % 10 ether + 1 gwei;
        uint256 start = alice.balance;
        _sell(alice, _buy(alice, value));
        assertLe(alice.balance, start);
        assertEq(address(pool).balance, pool.reserveBNB() + pool.platformCredit());
        assertEq(token.totalSupply() + token.totalBurned(), token.INITIAL_SUPPLY());
    }

    function testDividendsAccrueImmediatelyWithoutStake() public {
        uint256 out = _buy(alice, 1 ether);
        assertEq(vault.holderBalance(alice), out);
        assertEq(vault.eligibleSupply(), out);
        assertApprox(vault.earned(alice, address(0)), 0.024 ether, 1);
        uint256 earned = vault.earned(alice, address(0));
        uint256 before_ = alice.balance;
        vm.prank(alice);
        vault.claim(address(0), alice);
        assertEq(alice.balance - before_, earned);
        assertEq(token.balanceOf(alice), out);
        assertEq(vault.earned(alice, address(0)), 0);
        (bool stake,) = address(vault).call(abi.encodeWithSignature("stake(uint256)", 1));
        assertTrue(!stake);
    }

    function testSoldWalletKeepsPreviouslyEarnedDividends() public {
        _buy(alice, 1 ether);
        uint256 earned = vault.earned(alice, address(0));
        _sell(alice, token.balanceOf(alice));
        assertEq(vault.eligibleSupply(), 0);
        assertEq(vault.earned(alice, address(0)), earned);
        uint256 before_ = alice.balance;
        vm.prank(alice);
        vault.claim(address(0), alice);
        assertEq(alice.balance - before_, earned);
    }

    function testNewBuyerCannotTakeEarlierDistributedDividends() public {
        _buy(alice, 1 ether);
        uint256 previous = vault.earned(alice, address(0));
        _buy(bob, 1 ether);
        uint256 a = vault.earned(alice, address(0));
        uint256 b = vault.earned(bob, address(0));
        assertGe(a, previous);
        assertLe(b, 0.024 ether);
        assertApprox(a + b, 0.048 ether, 4);
    }

    function testQueuedFundsDistributeOnlyOnce() public {
        vault.notifyBNB{value: 1 ether}();
        assertEq(vault.queued(address(0)), 0.8 ether);
        _buy(alice, 1 ether);
        assertEq(vault.queued(address(0)), 0);
        assertApprox(vault.earned(alice, address(0)), 0.824 ether, 2);
        vm.expectRevert(DividendVault.InvalidAmount.selector);
        vault.distributeQueued(address(0));
    }

    function testCreatorOnlyModeAndAllBurnCombinations() public {
        _create(300, 0, 0, 0, address(0));
        _buy(bob, 1 ether);
        assertEq(token.rewardMode(), 0);
        assertEq(token.burnMode(), 0);
        assertEq(vault.earned(bob, address(0)), 0);
        assertEq(vault.creatorCredit(address(0)), 0.03 ether);
        _create(300, 100, 0, 0, address(0));
        _buy(bob, 1 ether);
        assertEq(token.burnMode(), 1);
        assertTrue(token.totalBurned() > 0);
        _create(300, 0, 6000, 2000, address(0));
        _buy(bob, 1 ether);
        assertEq(token.burnMode(), 2);
        assertEq(token.totalBurned(), 0);
        assertEq(vault.buybackBNB(), 0.006 ether);
        _create(300, 100, 6000, 2000, address(0));
        _buy(bob, 1 ether);
        assertEq(token.burnMode(), 3);
        assertTrue(token.totalBurned() > 0);
        assertEq(vault.buybackBNB(), 0.006 ether);
    }

    function testCurveBuybackBurnsAndKeepsDividendCreditsBacked() public {
        _create(300, 100, 6000, 2000, address(0));
        _buy(alice, 1 ether);
        uint256 before_ = token.totalBurned();
        uint256 oldBalance = token.balanceOf(address(vault));
        vm.prank(bob);
        vm.expectRevert(DividendVault.Unauthorized.selector);
        vault.executeBuyback(0.003 ether, 1, block.timestamp);
        vm.prank(alice);
        vault.executeBuyback(0.003 ether, 1, block.timestamp);
        assertTrue(token.totalBurned() > before_);
        assertTrue(vault.totalBuybackBurned() > 0);
        assertEq(token.balanceOf(address(vault)), oldBalance);
        assertGe(
            address(vault).balance,
            vault.earned(alice, address(0)) + vault.creatorCredit(address(0)) + vault.buybackBNB()
        );
        vm.prank(alice);
        vault.claim(address(0), alice);
        vm.prank(alice);
        vault.claimCreator(address(0), alice);
        assertGe(address(vault).balance, vault.buybackBNB());
    }

    function testBuybackAtGraduationTargetRevertsWithoutSpending() public {
        _create(300, 0, 6000, 2000, address(0));
        _buy(alice, 30 ether);
        uint256 credit = vault.buybackBNB();
        vm.prank(alice);
        vm.expectRevert();
        vault.executeBuyback(credit, 1, block.timestamp);
        assertEq(vault.buybackBNB(), credit);
        pool.graduate();
        uint256 burned = token.totalBurned();
        vm.prank(alice);
        vault.executeBuyback(credit / 2, 1, block.timestamp);
        assertTrue(token.totalBurned() > burned);
    }

    function testBuybackSlippageRevertsReserveAndBurn() public {
        _create(300, 100, 6000, 2000, address(0));
        _buy(alice, 1 ether);
        uint256 reserve = vault.buybackBNB();
        uint256 burned = token.totalBurned();
        vm.prank(alice);
        vm.expectRevert();
        vault.executeBuyback(reserve, type(uint256).max, block.timestamp);
        assertEq(vault.buybackBNB(), reserve);
        assertEq(token.totalBurned(), burned);
    }

    function testPostDexTaxAllocationBurnsOnlyBuybackShare() public {
        _create(300, 100, 6000, 2000, address(0));
        _buy(alice, 30 ether);
        pool.graduate();
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(token);
        vm.prank(bob);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 ether}(
            1, path, bob, block.timestamp
        );
        uint256 fees = token.balanceOf(address(token));
        uint256 before_ = token.totalBurned();
        token.distributeFees();
        assertEq(token.totalBurned() - before_, fees * 2000 / 10000);
        assertEq(vault.creatorCredit(address(token)), fees - fees * 6000 / 10000 - fees * 2000 / 10000);
        assertEq(token.balanceOf(address(vault)), fees - fees * 2000 / 10000);
        vm.prank(bob);
        vault.claim(address(token), bob);
        assertEq(vault.holderBalance(bob), token.balanceOf(bob));
    }

    function testTransferPreservesHistoryAndFutureRewardsFollowBalances() public {
        _buy(alice, 30 ether);
        pool.graduate();
        uint256 amount = token.balanceOf(alice) / 2;
        uint256 a = vault.earned(alice, address(0));
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(vault.earned(bob, address(0)), 0);
        assertEq(vault.earned(alice, address(0)), a);
        vault.notifyBNB{value: 1 ether}();
        assertApprox(vault.earned(bob, address(0)), 0.4 ether, 2);
        assertApprox(vault.earned(alice, address(0)) - a, 0.4 ether, 2);
        assertEq(vault.holderBalance(token.pair()), 0);
        assertEq(vault.holderBalance(address(pool)), 0);
    }

    function testExternalRewardFailureCannotFreezeTradingOrBNBClaims() public {
        MockAsset asset = new MockAsset();
        factory.setRewardAsset(address(asset), true);
        _create(300, 0, 8000, 0, address(asset));
        _buy(alice, 1 ether);
        asset.mint(address(this), 10 ether);
        asset.approve(address(vault), 10 ether);
        vault.depositReward(address(asset), 10 ether);
        assertApprox(vault.earned(alice, address(asset)), 10 ether, 1);
        assertEq(vault.creatorCredit(address(asset)), 0);
        factory.setRewardAsset(address(asset), false);
        asset.setBlocked(true);
        vm.prank(alice);
        vm.expectRevert();
        vault.claim(address(asset), alice);
        _sell(alice, token.balanceOf(alice));
        vm.prank(alice);
        vault.claim(address(0), alice);
        asset.setBlocked(false);
        vm.prank(alice);
        vault.claim(address(asset), alice);
        assertApprox(asset.balanceOf(alice), 10 ether, 1);
    }

    function testPregraduationCannotSeedExternalPairThroughClaims() public {
        uint256 out = _buy(alice, 1 ether);
        address pair = dexFactory.getPair(address(token), address(wbnb));
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(pair, out / 10);
        vm.startPrank(alice);
        token.approve(address(vault), out / 10);
        vault.depositReward(address(token), out / 10);
        vm.stopPrank();
        vm.prank(alice);
        vm.expectRevert(DividendVault.InvalidConfig.selector);
        vault.claim(address(token), pair);
        assertEq(token.balanceOf(pair), 0);
    }

    function testLegacyBuyRecipientCannotSeedGraduationPair() public {
        address futurePair=token.launchPair();
        vm.expectRevert(LaunchToken.CurveTransfersRestricted.selector);
        pool.buy{value:1 ether}(1,block.timestamp,futurePair);
        assertEq(token.balanceOf(futurePair),0);
        assertEq(pool.reserveBNB(),0);
        _buy(alice,25 ether);pool.graduate();assertTrue(pool.graduated());
    }

    function testRejectedClaimAndReentrancyPreserveAccounting() public {
        _buy(alice, 1 ether);
        RejectBNB reject = new RejectBNB();
        uint256 earned = vault.earned(alice, address(0));
        vm.prank(alice);
        vm.expectRevert(DividendVault.TransferFailed.selector);
        vault.claim(address(0), address(reject));
        assertEq(vault.earned(alice, address(0)), earned);
        ReenterClaim receiver = new ReenterClaim(vault);
        vm.prank(alice);
        vault.claim(address(0), address(receiver));
        assertTrue(receiver.attempted());
        assertEq(vault.earned(alice, address(0)), 0);
    }

    function testOnlyTokenCanChangeHolderSnapshots() public {
        vm.prank(bob);
        vm.expectRevert(DividendVault.Unauthorized.selector);
        vault.syncBalances(bob, 1 ether, alice, 0);
        vm.prank(bob);
        vm.expectRevert(DividendVault.Unauthorized.selector);
        vault.setPair(bob);
    }

    function testModeAndAllocationValidation() public {
        LaunchFactory.CreateParams memory p = _params(alice);
        p.buybackShareBps = 3000;
        p.burnMode = 3;
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
        p.buybackShareBps = 0;
        p.burnMode = 0;
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
        p.burnMode = 1;
        p.rewardMode = 0;
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
        p.rewardMode = 1;
        p.revenueBps = 501;
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
        p.revenueBps = 300;
        p.burnBps = 201;
        vm.prank(alice);
        vm.expectRevert(LaunchFactory.InvalidConfig.selector);
        factory.createToken{value: 0.01 ether}(p);
    }

    function testInitializersLocked() public {
        LaunchToken.Init memory p = LaunchToken.Init("X", "XX", "", alice, bob, 0, 0, 0, 0);
        address impl = factory.tokenImplementation();
        vm.expectRevert();
        token.initialize(p);
        vm.expectRevert();
        LaunchToken(impl).initialize(p);
        vm.expectRevert();
        vault.initialize(address(token), alice, address(pool), address(router), address(0), 8000, 0);
    }

    function testFuzz_ClaimsAndBurnKeepLiabilitiesBacked(uint96 input, uint16 fraction) public {
        uint256 amount = uint256(input) % 5 ether + 1 gwei;
        _buy(alice, amount);
        _buy(bob, amount);
        uint256 part = token.balanceOf(alice) * (uint256(fraction) % 10001) / 10000;
        vm.prank(alice);
        token.burn(part);
        vault.notifyBNB{value: 1 ether}();
        uint256 a = vault.earned(alice, address(0));
        uint256 b = vault.earned(bob, address(0));
        assertLe(a + b + vault.creatorCredit(address(0)), address(vault).balance);
        if (a > 0) {
            vm.prank(alice);
            vault.claim(address(0), alice);
        }
        if (b > 0) {
            vm.prank(bob);
            vault.claim(address(0), bob);
        }
        assertGe(address(vault).balance, vault.creatorCredit(address(0)));
        assertEq(vault.eligibleSupply(), token.balanceOf(alice) + token.balanceOf(bob));
        assertEq(token.totalSupply() + token.totalBurned(), token.INITIAL_SUPPLY());
    }
}
