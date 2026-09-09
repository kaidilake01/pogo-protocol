# Contributing

Open an issue describing the behavior you want to change, or submit a focused pull request with tests and documentation. Use English for public issues, pull requests and documentation.

Run `npm ci`, `npm run build`, `npm run typecheck`, `npm test`, and `npm run test:contracts` before proposing a change. Update generated SDK ABIs if Solidity interfaces change. Explain whether a change affects future deployments, existing upgradeable components, or immutable contracts that require redeployment.

Do not submit private keys, seed phrases, service credentials, live databases or signed-transaction journals. Do not include production asset transfers in reproduction steps. Keep third-party copyright and license notices intact.

Contract changes must describe storage compatibility, authority boundaries, arithmetic/rounding effects and migration behavior where applicable. An accepted source contribution does not by itself authorize a mainnet deployment.
