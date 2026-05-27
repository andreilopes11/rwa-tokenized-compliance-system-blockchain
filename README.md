# RWA Tokenized Compliance — Blockchain

Foundry contracts for permissioned RWA security tokens: production TREX-style contracts with explicit role separation, plus legacy migration contracts.

## Contract with `_docs`

| Item | Link |
|------|------|
| Spec | [`../_docs/contracts-erc3643.md`](../_docs/contracts-erc3643.md) |
| Deploy | [`../_docs/deployment.md`](../_docs/deployment.md) §A–B |
| Profile | `BLOCKCHAIN_PROFILE=mvp` (legacy) · `trex` (ERC-3643) |

## When to deploy which script

| Profile | Script | Use |
|---------|--------|-----|
| `mvp` | `script/deploy/DeployCore.s.sol` | Legacy registry (migration and local testing only) |
| `trex` | `script/deploy/DeployTREX.s.sol` | Production role-separated TREX-style deploy |

## Commands

```bash
npm install
npm test
npm run test:security
npm run deploy:local
npm run deploy:sepolia
```

## Layout

```text
src/legacy/identity/IdentityRegistry.sol
src/legacy/token/PermissionedToken.sol
src/trex/TrexIdentityRegistry.sol
src/trex/TrexModularCompliance.sol
src/trex/TrexToken.sol
script/deploy/DeployCore.s.sol
script/deploy/DeployTREX.s.sol
test/unit/
test/security/
deployments/{chainId}.json
deployments/{chainId}.backend.env
```

After deploy, run `bash ../root/scripts/sync-local-env.sh` from the monorepo root to propagate addresses.

## Compliance notes

- Production transfers enforce compliance at execution time through token hooks and modular compliance checks.
- Compliance and governance agent permissions are separated in deployment and runtime roles.
- No raw PII on-chain — only identity reference hashes and registry/compliance state.
