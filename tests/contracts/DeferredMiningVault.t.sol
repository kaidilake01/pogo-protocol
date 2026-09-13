// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {TestBase} from "./TestBase.sol";
import {MockAsset} from "./Mocks.sol";
import {DeferredMiningRevenueVault} from "../../contracts/src/MiningRevenueVault.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";

contract DeferredBindingMinerMock {
    address public immutable token;
    address public immutable vault;
    address public immutable fundingPool;
    constructor(address token_,address vault_,address funding_) {token=token_;vault=vault_;fundingPool=funding_;}
    function balanceOf(address) external pure returns(uint256) {return 0;}
    receive() external payable {}
}
contract DeferredMiningVaultTest is TestBase {
    MockAsset token;
    DeferredMiningRevenueVault vault;
    function setUp() public {
        token=new MockAsset();
        vault=new DeferredMiningRevenueVault(address(this));
        vault.initialize(address(token),address(this),address(this),address(0),address(this),
            LaunchTypes.Tax(300,300,0,0,10000,0,address(this),0));
        vm.deal(address(this),10 ether);
    }
    function testCounterfactualHolderWeightRemovedAndPastCreditClaimable() public {
        bytes32 salt=keccak256("future miner");
        bytes memory code=abi.encodePacked(type(DeferredBindingMinerMock).creationCode,abi.encode(address(token),address(vault),address(this)));
        address future=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),address(this),salt,keccak256(code))))));
        // Simulate the authenticated token transfer hook before CREATE2 deploys the recipient.
        vm.prank(address(token));vault.syncBalances(address(0),0,future,100 ether);
        vault.notifyQuote{value:1 ether}(1 ether);
        assertEq(vault.holderBalance(future),100 ether);assertEq(vault.eligibleSupply(),100 ether);
        assertEq(vault.earned(future,address(0)),1 ether);
        DeferredBindingMinerMock miner=new DeferredBindingMinerMock{salt:salt}(address(token),address(vault),address(this));
        assertEq(address(miner),future);
        vault.setStakingPool(future);
        assertEq(vault.holderBalance(future),0);assertEq(vault.eligibleSupply(),0);
        assertEq(vault.earned(future,address(0)),1 ether);
        // A separate holder gets only subsequent distributions; past credit is not confiscated.
        vm.prank(address(token));vault.syncBalances(address(0),0,address(0xa11ce),100 ether);
        vault.notifyQuote{value:1 ether}(1 ether);
        assertEq(vault.earned(future,address(0)),1 ether);
        assertEq(vault.earned(address(0xa11ce),address(0)),1 ether);
        vault.claimFor(future);
        assertEq(future.balance,1 ether);assertEq(vault.earned(future,address(0)),0);
    }
    function testBindingRejectsUnauthorizedNoCodeAndMismatchedReferences() public {
        DeferredBindingMinerMock good=new DeferredBindingMinerMock(address(token),address(vault),address(this));
        vm.prank(address(0xbad));vm.expectRevert();vault.setStakingPool(address(good));
        vm.expectRevert();vault.setStakingPool(address(0xdead));
        DeferredBindingMinerMock badToken=new DeferredBindingMinerMock(address(0xdead),address(vault),address(this));
        vm.expectRevert();vault.setStakingPool(address(badToken));
        DeferredBindingMinerMock badVault=new DeferredBindingMinerMock(address(token),address(0xdead),address(this));
        vm.expectRevert();vault.setStakingPool(address(badVault));
        DeferredBindingMinerMock badFunding=new DeferredBindingMinerMock(address(token),address(vault),address(0xdead));
        vm.expectRevert();vault.setStakingPool(address(badFunding));
        vault.setStakingPool(address(good));
        vm.expectRevert();vault.setStakingPool(address(good));
    }
}
