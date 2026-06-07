# T-REX implementation note

VaultGuard uses an **in-house ERC-3643 / T-REX-style** implementation under `src/trex/`
(production default) rather than vendoring the upstream Tokeny T-REX package. This keeps a single
OpenZeppelin 5.x / UUPS topology, avoids the OnchainID dependency, and preserves the existing
audited behaviour. The full stack (registries, modular compliance, modules, timelock, force-sync,
snapshot, distributor) is deployed per tenant via `script/deploy/DeployTenantTrex.s.sol`.

Spec: [`../../_docs/contracts-erc3643.md`](../../_docs/contracts-erc3643.md) §2.
Audit prep: [`../../_docs/stage2-trex-audit-prep.md`](../../_docs/stage2-trex-audit-prep.md).
