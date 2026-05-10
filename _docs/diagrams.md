# Diagrams

GitHub repository: <https://github.com/andreilopes11/rwa-tokenized-compliance-system.git>

## Context Diagram

```plantuml
@startuml
title RWA Tokenized Compliance System - Context
left to right direction

actor "Investor" as Investor
actor "Compliance Admin" as Admin
rectangle "RWA Tokenized\nCompliance System" as System
cloud "Banking or\nKYC Provider" as Banking
cloud "EVM Network" as Chain

Investor --> System : Submit documents\nand wallet
Admin --> System : Approve or revoke\neligibility
Banking --> System : Simulated validation\nresult
System --> Chain : Authorize identities\nand enforce transfers
Chain --> System : Events and balances
System --> Investor : Status and\ntoken activity
@enduml
```

## Container Diagram

```plantuml
@startuml
title RWA Tokenized Compliance System - Containers
left to right direction

package "Frontend" {
  component "Next.js Investor\nDashboard" as Dashboard
}

package "Backend" {
  component "Java Spring\nCompliance API" as API
  component "KYC AML\nValidator" as Validator
  component "Admin Signer\nSimulation" as Signer
}

package "Blockchain" {
  component "Permissioned\nToken" as Token
  component "Identity\nRegistry" as Registry
}

Dashboard --> API : KYC request
API --> Validator : Validate request
API --> Signer : Document hash\nand wallet
Signer --> Registry : addIdentity\ntransaction
Token --> Registry : Check sender\nand receiver
Registry --> API : Approval events
@enduml
```

## Component Diagram

```plantuml
@startuml
title RWA Tokenized Compliance System - Components
left to right direction

package "Investor Dashboard" {
  component "Wallet Connector" as WalletConnector
  component "KYC Request Form" as KycForm
  component "Token Activity View" as TokenActivity
}

package "Compliance Service" {
  component "KycController" as KycController
  component "Document Processor" as DocumentProcessor
  component "Compliance Validator" as ComplianceValidator
  component "Blockchain Signer" as BlockchainSigner
}

package "EVM Contracts" {
  component "PermissionedToken" as PermissionedToken
  component "IdentityManager" as IdentityManager
  component "Emergency Freeze\nControl" as FreezeControl
}

WalletConnector --> KycForm : Wallet address
KycForm --> KycController : Approval request
KycController --> DocumentProcessor : Hash document reference
KycController --> ComplianceValidator : Validate KYC AML rules
ComplianceValidator --> BlockchainSigner : Approved identity
BlockchainSigner --> IdentityManager : addIdentity(wallet, hash)
PermissionedToken --> IdentityManager : Check transfer eligibility
FreezeControl --> PermissionedToken : Pause or resume transfers
TokenActivity --> PermissionedToken : Read token status
@enduml
```

## Approval and Transfer Flow

```plantuml
@startuml
title RWA Tokenized Compliance System - Approval and Transfer Flow

actor Investor
participant "Frontend" as Frontend
participant "Backend" as Backend
participant "Admin Signer" as Signer
participant "Identity Registry" as Registry
participant "Permissioned Token" as Token

Investor -> Frontend : Connect wallet and submit document
Frontend -> Backend : POST KYC request
Backend -> Backend : Validate KYC and hash document
Backend -> Signer : Request identity authorization
Signer -> Registry : addIdentity(wallet, documentHash)
Registry --> Backend : IdentityAdded event
Backend --> Frontend : Approved with tx hash
Investor -> Token : Transfer token
Token -> Registry : Check sender and receiver
Registry --> Token : Valid identities
Token --> Investor : Transfer succeeds
@enduml
```
