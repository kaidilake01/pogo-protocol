// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchFactoryV4} from "./LaunchFactoryV4.sol";
import {QuoteAssetRegistry} from "./QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "./QuoteAssetRegistryV3.sol";
import {StandaloneTokenDeployer} from "./v4/StandaloneTokenDeployer.sol";
import {StandaloneCurveDeployer} from "./v4/StandaloneCurveDeployer.sol";

/// @notice No new storage: install matching economics and standalone deployers in one owner transaction.
contract LaunchFactoryV5 is LaunchFactoryV4 {
    function configureStandardLaunches(address registry_,address token_,address curve_) external onlyOwner {
        if(registry_.code.length==0||token_.code.length==0||curve_.code.length==0
            ||QuoteAssetRegistryV3(registry_).CURVE_VERSION()!=5
            ||StandaloneTokenDeployer(token_).factory()!=address(this)||StandaloneTokenDeployer(token_).KIND()!=1
            ||StandaloneCurveDeployer(curve_).factory()!=address(this)||StandaloneCurveDeployer(curve_).KIND()!=2
            ||address(standaloneVaultDeployer).code.length==0)revert InvalidConfig();
        quoteRegistry=QuoteAssetRegistry(registry_);
        standaloneTokenDeployer=StandaloneTokenDeployer(token_);
        standaloneCurveDeployer=StandaloneCurveDeployer(curve_);
        templateVersionV3++;
        emit TemplatesV3Updated(templateVersionV3,registry_,tokenImplementationV3,vaultImplementationV3,poolImplementationV3);
        emit StandaloneDeployersConfigured(token_,curve_,address(standaloneVaultDeployer));
    }
}
