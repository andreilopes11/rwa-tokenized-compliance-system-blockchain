# Deploy — Sepolia TREX (first production-oriented chain deploy)

Contracts are **not** deployed to Elastic Beanstalk or Vercel. Deploy with Foundry against an RPC provider (Alchemy / Infura / public Sepolia endpoint).

**First target: Ethereum Sepolia + TREX** (`DeployTREX.s.sol`). Mainnet waits for real KMS EIP-155 + external audit.

## Current Sepolia deployment (live)

Source of truth (no secrets): [`config/sepolia-addresses.json`](config/sepolia-addresses.json).  
Full local artifact (gitignored): `deployments/11155111.json`.

| Contract | Address |
|----------|---------|
| Identity Registry | `0xDf47E753589f6f4337999DC72bF0530301AEDe5b` |
| Modular Compliance | `0xAd8C670c58a5e00baA3BCC5dd9C1eE607EBE53EB` |
| Token | `0xC85bB59cbaffE561BC5A490BEeb37eC9Fb8c92b0` |
| Chain ID | `11155111` |
| Block | `11307738` |

Explorer: [IR](https://sepolia.etherscan.io/address/0xDf47E753589f6f4337999DC72bF0530301AEDe5b) · [MC](https://sepolia.etherscan.io/address/0xAd8C670c58a5e00baA3BCC5dd9C1eE607EBE53EB) · [Token](https://sepolia.etherscan.io/address/0xC85bB59cbaffE561BC5A490BEeb37eC9Fb8c92b0)

### Copy into Elastic Beanstalk

```text
RPC_URL=<your Sepolia Alchemy HTTPS URL>
CHAIN_ID=11155111
BLOCKCHAIN_MODE=trex
IDENTITY_REGISTRY_ADDRESS=0xDf47E753589f6f4337999DC72bF0530301AEDe5b
TOKEN_ADDRESS=0xC85bB59cbaffE561BC5A490BEeb37eC9Fb8c92b0
MODULAR_COMPLIANCE_ADDRESS=0xAd8C670c58a5e00baA3BCC5dd9C1eE607EBE53EB
APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=false
APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY=<deployer private key from local sepolia.json — never commit>
```

### Copy into Vercel

```text
NEXT_PUBLIC_CHAIN_ID=11155111
NEXT_PUBLIC_RPC_URL=<your Sepolia Alchemy HTTPS URL>
NEXT_PUBLIC_BLOCK_EXPLORER_URL=https://sepolia.etherscan.io
NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=0xDf47E753589f6f4337999DC72bF0530301AEDe5b
NEXT_PUBLIC_TOKEN_ADDRESS=0xC85bB59cbaffE561BC5A490BEeb37eC9Fb8c92b0
BACKEND_API_BASE_URL=http://rwatokenizedcomplianceapi-env.eba-ddsh8y8v.eu-north-1.elasticbeanstalk.com
```

Do **not** put private keys on Vercel. Local Anvil addresses stay in `contracts.generated.ts` for `stack.ps1`.

## Prerequisites

1. Foundry (`forge`, `cast`) on PATH
2. Sepolia ETH on the deployer + four agent wallets (faucet)
3. Fill [`config/sepolia.json`](config/sepolia.json) locally (**do not commit real keys or RPC secrets**):
   - `rpcUrl` / `sepoliaRpcUrl` — HTTPS Sepolia RPC
   - `privateKey` — deployer
   - `governanceAgentPrivateKey`, `complianceAgentPrivateKey`, `lifecycleAgentPrivateKey`, `transferManagerAgentPrivateKey` — SoD agents (must not overlap)

## Deploy

```bash
cd rwa-tokenized-compliance-system-blockchain
# edit config/sepolia.json with real values (gitignored secrets preferred: keep file local-only edits unstaged)
npm run deploy:sepolia
```

This runs `scripts/deploy-sepolia.sh`, which:

1. Loads `config/sepolia.json`
2. Forces `CHAIN_ID=11155111`
3. Broadcasts `DeployTREX`
4. Writes `deployments/11155111.json` and `deployments/11155111.backend.env`

## Artifacts → EB / Vercel

From `deployments/11155111.json` (field names may vary slightly; see JSON):

| Consumer | Variables |
|----------|-----------|
| **EB** | `RPC_URL`, `CHAIN_ID=11155111`, `BLOCKCHAIN_MODE=trex`, `IDENTITY_REGISTRY_ADDRESS`, `TOKEN_ADDRESS`, `MODULAR_COMPLIANCE_ADDRESS`, `APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY` (drill) |
| **Vercel** | `NEXT_PUBLIC_CHAIN_ID=11155111`, `NEXT_PUBLIC_RPC_URL`, `NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS`, `NEXT_PUBLIC_TOKEN_ADDRESS`, `NEXT_PUBLIC_BLOCK_EXPLORER_URL=https://sepolia.etherscan.io` |

Prefer copying from `deployments/11155111.backend.env` into the EB console (never commit that file if it contains a private key).

## Smoke

1. `cast code <identityRegistry> --rpc-url $SEPOLIA_RPC_URL` — non-empty
2. `cast code <token> --rpc-url $SEPOLIA_RPC_URL` — non-empty
3. Open tx hashes on https://sepolia.etherscan.io
4. Backend EB health `/actuator/health` shows blockchain UP after wiring
5. Frontend investor reads resolve on Sepolia

## Local vs Sepolia

| Command | Network | Profile |
|---------|---------|---------|
| `npm run local:up` | Anvil `11155111` | **trex** (same `DeployTREX.s.sol` as Sepolia — parity) |
| `npm run deploy:sepolia` | Sepolia `11155111` | **trex** (production path) |
| `npm run deploy:sepolia:legacy` | Sepolia | mvp (legacy `src/legacy/`, migration only) |

## Security

- Never commit funded private keys or Alchemy API keys
- Use separate agent keys for SoD; DeployTREX rejects overlapping governance/compliance keys
- Four-eyes force-sync: `ForceSyncGovernor` is 2-of-N. Under the two-role model force-sync is a
  SUPER_ADMIN action, so **provision at least two distinct SUPER_ADMIN accounts** as governor
  owners — a single admin cannot both initiate and approve (`DuplicateApproval`).
- Sepolia drill on EB: `APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=false` + vault-injected key
- Mainnet: KMS required; do not reuse Sepolia keys

## Related

- Backend: `../rwa-tokenized-compliance-system-backend/DEPLOY-EB.md`
- Frontend: `../rwa-tokenized-compliance-system-frontend/DEPLOY-VERCEL.md`
