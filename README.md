# RWA Tokenized Compliance — Blockchain

Foundry contracts for Portfolio Baseline (MVP) and T-REX target (Testnet Public).

## Contract with `_docs`

| Item | Link |
|------|------|
| Spec | [`../_docs/contracts-erc3643.md`](../_docs/contracts-erc3643.md) |
| Deploy | [`../_docs/deployment.md`](../_docs/deployment.md) §A–B |
| Profile | `BLOCKCHAIN_PROFILE=mvp` (today) · `trex` after T-REX install |

## When to deploy which script

| Profile | Script | Use |
|---------|--------|-----|
| `mvp` | `script/deploy/DeployCore.s.sol` | Local Anvil, Sepolia MVP regression |
| `trex` | `script/deploy/DeployTREX.s.sol` | **PLANNED** — requires `lib/T-REX` (see `lib/T-REX/README.md`) |

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
script/deploy/DeployCore.s.sol
script/deploy/DeployTREX.s.sol   # PLANNED — reverts until T-REX wired
test/unit/
test/security/
deployments/{chainId}.json
deployments/{chainId}.backend.env
```

After deploy, run `bash ../root/scripts/sync-local-env.sh` from the monorepo root to propagate addresses.
