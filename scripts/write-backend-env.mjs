#!/usr/bin/env node
/**
 * Writes deployments/{chainId}.backend.env from deployments/{chainId}.json
 * for root/scripts/stack.ps1 sync and backend consumers.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const deploymentChainHint = process.env.CHAIN_ID ?? process.env.LOCAL_CHAIN_ID;
let chainId = deploymentChainHint ?? "11155111";
let jsonPath = path.join(root, "deployments", `${chainId}.json`);

// If CHAIN_ID unset but Sepolia artifact exists, prefer it over Anvil default.
if (!deploymentChainHint && !fs.existsSync(jsonPath) && fs.existsSync(path.join(root, "deployments", "11155111.json"))) {
  chainId = "11155111";
  jsonPath = path.join(root, "deployments", `${chainId}.json`);
}

const envPath = path.join(root, "deployments", `${chainId}.backend.env`);

if (!fs.existsSync(jsonPath)) {
  console.error(`Missing ${jsonPath}. Run deploy:local or deploy:sepolia first.`);
  process.exit(1);
}

const deployment = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
const profile = deployment.profile ?? "mvp";
const registry =
  deployment.identityRegistry ?? deployment.identityRegistryAddress;
const token =
  deployment.permissionedToken ?? deployment.token ?? deployment.tokenAddress;
const rpcUrl = process.env.RPC_URL ?? process.env.SEPOLIA_RPC_URL ?? "http://127.0.0.1:8545";
const privateKey = process.env.ADMIN_PRIVATE_KEY ?? process.env.PRIVATE_KEY ?? "";

if (!registry || !token) {
  console.error("deployment JSON must include identityRegistry and permissionedToken (or token).");
  process.exit(1);
}

const modular =
  deployment.modularCompliance ??
  deployment.modularComplianceAddress ??
  deployment.MODULAR_COMPLIANCE_ADDRESS;

const lines = [
  `BLOCKCHAIN_PROFILE=${profile}`,
  `BLOCKCHAIN_MODE=${deployment.blockchainMode ?? profile}`,
  `RPC_URL=${rpcUrl}`,
  `CHAIN_ID=${chainId}`,
  `IDENTITY_REGISTRY_ADDRESS=${registry}`,
  `TOKEN_ADDRESS=${token}`
];

if (modular) {
  lines.push(`MODULAR_COMPLIANCE_ADDRESS=${modular}`);
}

if (privateKey) {
  lines.push(`ADMIN_PRIVATE_KEY=${privateKey}`);
}

fs.mkdirSync(path.dirname(envPath), { recursive: true });
fs.writeFileSync(envPath, `${lines.join("\n")}\n`);
console.log(`Wrote ${envPath}`);
