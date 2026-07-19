# Deploy — Sepolia TREX (first production-oriented chain deploy)

Contracts are **not** deployed to Elastic Beanstalk or Vercel. Deploy with Foundry against an RPC provider (Alchemy / Infura / public Sepolia endpoint).

**First target: Ethereum Sepolia + TREX** (`DeployTREX.s.sol`). Mainnet waits for real KMS EIP-155 + external audit.

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
| `npm run local:up` | Anvil `31337` | **mvp** (legacy IdentityRegistry + PermissionedToken) |
| `npm run deploy:sepolia` | Sepolia `11155111` | **trex** (production path) |
| `npm run deploy:sepolia:legacy` | Sepolia | mvp (migration only) |

## Security

- Never commit funded private keys or Alchemy API keys
- Use separate agent keys for SoD; DeployTREX rejects overlapping governance/compliance keys
- Sepolia drill on EB: `APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=false` + vault-injected key
- Mainnet: KMS required; do not reuse Sepolia keys

## Related

- Backend: `../rwa-tokenized-compliance-system-backend/DEPLOY-EB.md`
- Frontend: `../rwa-tokenized-compliance-system-frontend/DEPLOY-VERCEL.md`
