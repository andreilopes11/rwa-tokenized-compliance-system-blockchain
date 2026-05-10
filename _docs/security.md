# Security

GitHub repository: <https://github.com/andreilopes11/rwa-tokenized-compliance-system.git>

## Security Goals

- Prevent unauthorized wallets from holding or transferring regulated tokens.
- Keep sensitive identity data off-chain.
- Make compliance decisions auditable through events.
- Reduce blast radius if the backend or frontend is compromised.
- Provide an emergency pause path for incidents.

## Threat Model

| Threat                          | Risk                                              | Mitigation                                                                                  |
| ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Transfer to non-approved wallet | Regulated asset ownership escapes compliance      | Enforce receiver approval in token transfer hook                                            |
| Transfer from revoked wallet    | Revoked investor moves assets after status change | Enforce sender approval in token transfer hook                                              |
| Raw document exposure           | Privacy and GDPR risk                             | Store only hashes or storage references on-chain                                            |
| Backend key compromise          | Attacker approves identities                      | Use least-privilege signer, multisig or KMS in production, and monitor approval events      |
| Replay approval                 | Old signature reused after revocation             | Include nonce, chain id, contract address, and expiry in future signed authorization design |
| Emergency incident              | Transfers continue during investigation           | Implement emergency freeze and test it                                                      |

## Expected Test Scenarios

- Approved investor can receive tokens.
- Non-approved investor cannot receive tokens.
- Revoked investor cannot send tokens.
- Revoked investor cannot receive tokens.
- Emergency freeze blocks transfers.
- Approval emits expected event with identity hash reference.
- Duplicate approval is handled consistently.
- Zero address and malformed wallet inputs are rejected.

## Audit Checklist

- Transfer hook cannot be bypassed by mint, burn, or delegated transfer paths.
- Owner/admin functions are access controlled.
- Events provide enough audit evidence without exposing private data.
- Backend never logs private keys or raw documents.
- Environment variables are used for sensitive runtime configuration.
- Local demo keys are clearly marked as unsafe for production.
- ADRs document trust assumptions around the admin signer.

## Production Hardening Notes

The portfolio version can use a single admin signer to keep the demo practical. A production-grade version should move toward multisig governance, hardware or cloud key management, oracle decentralization, rate limits, monitoring, and formal compliance module separation.
