# VaultGuard RWA — Blockchain (Production T-REX)

Foundry contracts for **production** ERC-3643 / T-REX-style permissioned RWA tokens with explicit on-chain separation of duties. Legacy MVP contracts remain under `src/legacy/` for migration testing only.

## Contract specification

| Item | Link |
|------|------|
| Normative spec | [`../_docs/contracts-erc3643.md`](../_docs/contracts-erc3643.md) |
| Deploy & keys | [`../_docs/deployment.md`](../_docs/deployment.md) |
| Release gate G1 | [`../_docs/testnet-evidence.md`](../_docs/testnet-evidence.md) |

## Production deploy (default)

| Script | Profile | Use |
|--------|---------|-----|
| `script/deploy/DeployTREX.s.sol` | `trex` | **Production** — Identity Registry, Modular Compliance, Token, role-separated agents |
| `script/deploy/DeployCore.s.sol` | `mvp` | Legacy only (non-production) |

### Agent roles (on-chain SoD)

| Agent | Contract roles | Allowed operations |
|-------|----------------|-------------------|
| **Governance** | `GOVERNANCE_ROLE` on token + modular compliance | `pause` / `unpause`, `setPaused`, `setLimits` |
| **Compliance** | `COMPLIANCE_ROLE` on identity registry | `registerIdentity`, `deleteIdentity` / `removeIdentity` |
| **Lifecycle** | `LIFECYCLE_ROLE` on token | `mint` (to verified wallets only) |
| **Transfer manager** | `TRANSFER_MANAGER_ROLE` on token | `forceTransfer` (policy-bound recovery) |

Deploy-time assertions reject overlapping governance/compliance keys and zero addresses.

### Deployment artifact

After `forge script ... DeployTREX`, addresses are written to:

```text
deployments/{chainId}.json
```

Fields: `profile`, `blockchainMode`, `identityRegistry`, `modularCompliance`, `token`, `superAdmin`, `governanceAgent`, `complianceAgent`, `lifecycleAgent`, `transferManagerAgent`.

Run `node scripts/write-backend-env.mjs` (or monorepo `sync-local-env.sh`) to propagate addresses to the backend.

## Commands

```bash
npm install
npm run build          # forge build
npm test               # unit + security
npm run test:security  # test/security/*.t.sol only
npm run deploy:local   # Anvil + DeployTREX
npm run deploy:sepolia
```

Requires [Foundry](https://book.getfoundry.sh/) (`forge` on PATH).

## Layout

```text
src/trex/TrexIdentityRegistry.sol   # COMPLIANCE_ROLE identity lifecycle
src/trex/TrexModularCompliance.sol  # GOVERNANCE_ROLE pause + limits; canTransfer
src/trex/TrexToken.sol              # execution-time compliance in _update
src/legacy/                         # non-production MVP contracts
script/deploy/DeployTREX.s.sol
test/unit/Trex*.t.sol
test/security/TrexComplianceSecurity.t.sol
deployments/{chainId}.json
```

## Security invariants

- **No PII on-chain** — only `bytes32` identity reference hashes.
- **`canTransfer` before balance mutation** — `_update` checks registry verification and modular compliance.
- **Revocation is immediate** — `deleteIdentity` blocks send and receive on the next transfer.
- **Custom errors** — `NonCompliantSender`, `NonCompliantRecipient`, `TokenPaused`, `TransferNotCompliant`, `IdentityAlreadyRegistered`, etc.

## Acceptance checklist

- [ ] `forge build && forge test` pass
- [ ] Unauthorized agent cannot `registerIdentity` or `pause`
- [ ] Revoked identity cannot send or receive
- [ ] Mint to non-compliant wallet reverts
- [ ] G1 evidence recorded in [`testnet-evidence.md`](../_docs/testnet-evidence.md) for target network
