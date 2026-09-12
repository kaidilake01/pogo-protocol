// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchFactoryV6} from "./LaunchFactoryV6.sol";
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV5} from "./QuoteAssetRegistryV5.sol";
import {StandaloneTokenDeployer} from "./StandaloneTokenDeployer.sol";
import {StandaloneCurveDeployer} from "./StandaloneCurveDeployer.sol";
import {StandaloneVaultDeployer} from "./StandaloneVaultDeployer.sol";

/// @notice No storage additions; immutable mining terms are installed only for future launches.
contract LaunchFactoryV7 is LaunchFactoryV6 {
    uint256 public constant MINING_LAUNCH_VERSION=1;
    function configureMiningLaunches(address registry_,address curve_,address vault_) external onlyOwner {
        if(registry_.code.length==0||curve_.code.length==0||vault_.code.length==0
            ||QuoteAssetRegistryV5(registry_).CURVE_VERSION()!=6
            ||StandaloneCurveDeployer(curve_).factory()!=address(this)||StandaloneCurveDeployer(curve_).KIND()!=2
            ||StandaloneVaultDeployer(vault_).factory()!=address(this)||StandaloneVaultDeployer(vault_).KIND()!=3
            ||address(standaloneTokenDeployer).code.length==0)revert InvalidConfig();
        quoteRegistry=QuoteAssetRegistry(registry_);
        standaloneCurveDeployer=StandaloneCurveDeployer(curve_);
        standaloneVaultDeployer=StandaloneVaultDeployer(vault_);
        templateVersionV3++;
        emit TemplatesV3Updated(templateVersionV3,registry_,tokenImplementationV3,vaultImplementationV3,poolImplementationV3);
        emit StandaloneDeployersConfigured(address(standaloneTokenDeployer),curve_,vault_);
    }
}
