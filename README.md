# RWA Tokenized Compliance System Blockchain

This repository is focused on the EVM backend layer of the project: Solidity contracts, deployment scripts, and compliance tests for a permissioned tokenized asset flow.

The documents in `/_docs/**` were preserved as historical reference for the broader project, but this repository is now organized strictly around the blockchain layer.

## Scope

- `IdentityRegistry`: approves and revokes investor identities.
- `PermissionedToken`: permissioned ERC-20 with identity checks on mint, transfer, and burn.
- Local and Sepolia deployment through Foundry.
- Unit tests focused on on-chain behavior.

## Structure

```text
src/
  identity/IdentityRegistry.sol
  interfaces/IIdentityRegistry.sol
  token/PermissionedToken.sol
script/
  deploy/DeployCore.s.sol
test/
  unit/IdentityRegistry.t.sol
  unit/PermissionedToken.t.sol
utils/
  foundry/Vm.sol
```

## Prerequisites

- Foundry (`forge`, `cast`, `anvil`)
- Node.js + npm

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install the Solidity dependency:

```bash
npm install
```

## Environment Variables

Use `.env.example` as the base:

```bash
cp .env.example .env
```

Main variables:

- `RPC_URL`: local or remote RPC endpoint
- `CHAIN_ID`: target chain id
- `PRIVATE_KEY`: deployer private key
- `SEPOLIA_RPC_URL`: Sepolia RPC endpoint
- `ETHERSCAN_API_KEY`: optional verification key

## Local Development

Build:

```bash
npm run build
```

Tests:

```bash
npm test
```

Unit tests:

```bash
npm run test:unit
```

## Local Bootstrap

Recommended single script to clear previous artifacts, check tooling, start `anvil`, build, test, deploy, and generate backend-ready environment files:

```bash
npm run local:fresh
```

If you want to start the environment without deleting the previous artifacts:

```bash
npm run local:up
```

This flow:

- validates `node`, `npm`, `forge`, `cast`, and `anvil`
- stops a previous `anvil` process started by the scripts
- clears `cache/`, `out/`, `broadcast/`, `deployments/`, and temporary files under `.local/`
- installs `node_modules` when `@openzeppelin/contracts` is missing
- runs `forge build`
- runs `forge test -vvv`
- starts a local `anvil` node at `127.0.0.1:8545` when one is not already running
- deploys `IdentityRegistry` and `PermissionedToken`
- generates files for backend consumption

Generated files:

- `deployments/31337.json`
- `deployments/31337.backend.env`

The `deployments/31337.backend.env` file includes:

- `RPC_URL`
- `CHAIN_ID`
- `IDENTITY_REGISTRY_ADDRESS`
- `TOKEN_ADDRESS`
- `ADMIN_PRIVATE_KEY`

If you only want to validate the environment:

```bash
npm run check:tooling
```

If you want to stop the `anvil` instance started by the scripts:

```bash
npm run local:down
```

## Manual Local Deployment

Manual fallback if you want to run each step separately:

```bash
anvil --host 127.0.0.1 --port 8545 --chain-id 31337
```

In another terminal:

```bash
npm run deploy:local
```

## Sepolia Deployment

Set `SEPOLIA_RPC_URL`, `PRIVATE_KEY`, and optionally `ETHERSCAN_API_KEY` if you want verification.

```bash
npm run deploy:sepolia
```

## Cleanup Notes

- The previous `README` described a Java backend, a Next.js frontend, and scripts that do not exist in this repository.
- The contract structure was separated by domain (`identity`, `token`, `interfaces`).
- The token contract no longer emits the old debug event because it was not part of the business rule.
- The tests were split by unit responsibility.
- The configuration now ignores real Foundry artifacts and generated deployment directories.
