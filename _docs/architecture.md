# Architecture

GitHub repository: <https://github.com/andreilopes11/rwa-tokenized-compliance-system.git>

## System Context

The RWA Tokenized Compliance System serves regulated asset issuers that need to tokenize real-world assets without allowing unrestricted token transfers. Investors interact through a wallet-based portal, compliance operators review eligibility off-chain, and the blockchain enforces transfer restrictions.

## C4 Level 1: Context

- Investor submits documents, connects a wallet, buys or receives tokens, and transfers only to approved addresses.
- Compliance Admin reviews KYC/AML status and controls investor eligibility.
- RWA System coordinates off-chain validation and on-chain enforcement.
- External Banking or KYC Systems are represented as simulated integrations in the portfolio version.
- EVM Network stores token balances, identity eligibility, events, and compliance-relevant transfer outcomes.

## C4 Level 2: Containers

- Investor Dashboard: Next.js application for wallet connection, onboarding status, document upload simulation, and token visibility.
- Compliance Service: Java/Spring Boot API for KYC workflow, document hashing, approval decisions, and blockchain transaction orchestration.
- Permissioned Token Contracts: Solidity contracts that represent ownership and prevent transfers involving non-approved identities.
- Oracle/Admin Signer Simulation: controlled integration point that submits compliance decisions on-chain during the portfolio phase.
- Observability and Scripts: future deployment, demo, and audit evidence assets.

## Core Flow

1. Investor connects wallet and submits a KYC request.
2. Compliance service validates the request and stores only a document hash reference.
3. Backend signs an on-chain `addIdentity` transaction through the admin signer simulation.
4. Smart contract emits an identity approval event.
5. Token transfers call compliance checks before state changes.
6. Revoked or unknown addresses are rejected by the token contract.

## On-Chain Boundary

The blockchain layer owns:

- Token balances and transfer restrictions.
- Identity approval flags or registry references.
- Immutable compliance events.
- Emergency freeze state.

The blockchain layer does not own:

- Raw documents.
- Personal identity details.
- KYC scoring logic.
- Banking integration state.

## Off-Chain Boundary

The backend layer owns:

- KYC/AML workflow simulation.
- Document hashing and storage references.
- Admin signing orchestration.
- API contracts for frontend and future enterprise integrations.

The backend layer must not bypass on-chain transfer restrictions. Even if the backend is compromised, the token contract remains the final enforcement point.

## Implementation Direction

The first implementation should start with `blockchain/evm`, then add `backend/compliance-service`, then connect `frontend/investor-dashboard`. The oracle simulation can begin as an admin signer and later be replaced by Chainlink Functions or another decentralized oracle pattern.
