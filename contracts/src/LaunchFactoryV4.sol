// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchFactoryV3} from "./LaunchFactoryV3.sol";
import {StandaloneTokenDeployer} from "./v4/StandaloneTokenDeployer.sol";
import {StandaloneCurveDeployer} from "./v4/StandaloneCurveDeployer.sol";
import {StandaloneVaultDeployer} from "./v4/StandaloneVaultDeployer.sol";

/// @notice V3 ABI and accounting with standalone project contracts. All prior storage is preserved.
contract LaunchFactoryV4 is LaunchFactoryV3 {
    StandaloneTokenDeployer public standaloneTokenDeployer;
    StandaloneCurveDeployer public standaloneCurveDeployer;
    StandaloneVaultDeployer public standaloneVaultDeployer;
    uint256 public constant STANDALONE_VERSION=1;
    event StandaloneDeployersConfigured(address token,address curve,address vault);
    error LegacyCreationDisabled();
    function createToken(CreateParams calldata) external payable override returns(address){revert LegacyCreationDisabled();}
    function setStandaloneDeployers(address token_,address curve_,address vault_) external onlyOwner {
        if(token_.code.length==0||curve_.code.length==0||vault_.code.length==0)revert InvalidConfig();
        if(StandaloneTokenDeployer(token_).factory()!=address(this)||StandaloneTokenDeployer(token_).KIND()!=1
            ||StandaloneCurveDeployer(curve_).factory()!=address(this)||StandaloneCurveDeployer(curve_).KIND()!=2
            ||StandaloneVaultDeployer(vault_).factory()!=address(this)||StandaloneVaultDeployer(vault_).KIND()!=3)revert InvalidConfig();
        standaloneTokenDeployer=StandaloneTokenDeployer(token_);standaloneCurveDeployer=StandaloneCurveDeployer(curve_);standaloneVaultDeployer=StandaloneVaultDeployer(vault_);
        emit StandaloneDeployersConfigured(token_,curve_,vault_);
    }
    function tokenDeploymentConfig() external view returns(address deployer,bytes32 initCodeHash){
        deployer=address(standaloneTokenDeployer);if(deployer==address(0))revert InvalidConfig();
        initCodeHash=standaloneTokenDeployer.initCodeHash();
    }
    function launchConfigHash(address quote) public view override returns(bytes32){
        return keccak256(abi.encode(super.launchConfigHash(quote),address(standaloneTokenDeployer),address(standaloneCurveDeployer),address(standaloneVaultDeployer)));
    }
    function predictTokenV3(address creator,bytes32 salt) public view override returns(address){
        return standaloneTokenDeployer.predict(effectiveSalt(creator,salt));
    }
    function _deployTokenV3(bytes32 salt) internal override returns(address){return standaloneTokenDeployer.deploy(salt);}
    function _deployPoolV3() internal override returns(address){return standaloneCurveDeployer.deploy();}
    function _deployVaultV3() internal override returns(address){return standaloneVaultDeployer.deploy();}
}
