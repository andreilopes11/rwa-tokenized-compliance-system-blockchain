# Rules and Definitions

GitHub repository: <https://github.com/andreilopes11/rwa-tokenized-compliance-system.git>

## Glossary

- RWA: Real-world asset represented by an on-chain token.
- Permissioned Token: Token that can only be held or transferred by approved identities.
- KYC: Know Your Customer validation performed off-chain.
- AML: Anti-money laundering screening performed off-chain.
- Identity Hash: Non-sensitive hash or reference proving that an off-chain identity record exists.
- Whitelist: On-chain approval state that allows an address to receive and transfer tokens.
- Admin Signer: Portfolio-stage trusted signer that submits compliance decisions on-chain.
- Issuer: Organization responsible for tokenizing the asset and operating compliance.

## Roles

- Investor: Requests eligibility, holds tokens, and initiates transfers.
- Compliance Admin: Approves, rejects, or revokes investor eligibility.
- Backend Service: Applies off-chain rules and submits authorization transactions.
- Contract Owner or Compliance Contract: Manages identity approval and emergency controls.
- Auditor: Reviews events, documentation, tests, and security assumptions.

## Business Rules

- A wallet must be approved before it can receive tokenized assets.
- A wallet must remain approved to transfer tokenized assets.
- Raw identity documents must never be stored on-chain.
- Revoked investors must be blocked from sending and receiving tokens.
- Approval and revocation actions must emit auditable events.
- Emergency freeze must stop token movement while preserving balances.
- The portfolio version may use simulated KYC/AML, but the interface must make replacement with a real provider straightforward.

## Technical Invariants

- Token transfer checks must run before balance mutation.
- Minting must only target approved addresses, except for controlled deployment initialization if explicitly documented.
- Burning must not leak around compliance checks unless a regulator or issuer-controlled process requires it and the exception is tested.
- Identity approval must be idempotent or reject duplicates consistently.
- Identity revocation must not delete historical events.
- Backend approval state must not be treated as final unless reflected on-chain.

## Out of Scope for Initial Implementation

- Real KYC provider integration.
- Production custody or fiat settlement.
- Legal claim enforcement outside the token model.
- Production decentralized oracle deployment.
- Secondary-market exchange integration.
