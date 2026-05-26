# RWA Tokenized Compliance — Blockchain

Foundry contracts for permissioned RWA security tokens: legacy identity registry and ERC-3643 / T-REX deploy path.

## Contract with `_docs`

| Item | Link |
|------|------|
| Spec | [`../_docs/contracts-erc3643.md`](../_docs/contracts-erc3643.md) |
| Deploy | [`../_docs/deployment.md`](../_docs/deployment.md) §A–B |
| Profile | `BLOCKCHAIN_PROFILE=mvp` (legacy) · `trex` (ERC-3643) |

## When to deploy which script

| Profile | Script | Use |
|---------|--------|-----|
| `mvp` | `script/deploy/DeployCore.s.sol` | Legacy registry — local Anvil, Sepolia |
| `trex` | `script/deploy/DeployTREX.s.sol` | ERC-3643 / T-REX — requires `lib/T-REX` |

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
script/deploy/DeployTREX.s.sol
test/unit/
test/security/
deployments/{chainId}.json
deployments/{chainId}.backend.env
```

After deploy, run `bash ../root/scripts/sync-local-env.sh` from the monorepo root to propagate addresses.

## Compliance notes

- Transfers enforce identity registry eligibility on every `transfer` / `transferFrom`.
- No raw PII on-chain — only identity hashes and registry state.
- Issuer `pause` / `unpause` for emergency compliance controls.
