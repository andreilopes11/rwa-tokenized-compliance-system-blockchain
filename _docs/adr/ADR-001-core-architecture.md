# ADR-001: Core Architecture for Permissioned RWA Tokenization

GitHub repository: <https://github.com/andreilopes11/rwa-tokenized-compliance-system.git>

## Status

Accepted for portfolio baseline.

## Context

Real-world asset tokenization needs public-chain settlement and auditability, but regulated assets cannot move freely between anonymous wallets. KYC/AML checks require sensitive data processing that is expensive, private, and unsuitable for public blockchain storage.

## Decision

Use a hybrid architecture:

- Solidity contracts enforce ownership and transfer restrictions on an EVM network.
- Java/Spring Boot performs off-chain KYC/AML simulation and transaction orchestration.
- Next.js provides the investor workflow.
- An admin signer simulation submits compliance decisions on-chain for the portfolio version.
- Raw identity data remains off-chain; only hashes, registry state, and events are stored on-chain.

## Consequences

This design demonstrates realistic separation of concerns between regulated enterprise workflows and immutable blockchain enforcement. It introduces a trusted signer in the portfolio version, which must be documented as a production hardening target. The architecture can later evolve to Chainlink Functions, API3, multisig governance, or a fuller ERC-3643/T-REX implementation.
