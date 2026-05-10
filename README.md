# RWA Tokenized Compliance System Blockchain

Repositório focado no backend EVM do projeto: contratos Solidity, script de deploy e testes de compliance para um token permissionado de ativos tokenizados.

Os documentos em `/_docs/**` foram preservados como referência histórica do projeto maior, mas esta base agora está organizada apenas para a camada blockchain.

## Escopo

- `IdentityRegistry`: registra e revoga identidades aprovadas pelo operador.
- `PermissionedToken`: ERC-20 permissionado com checagem de identidade em mint, transfer e burn.
- Deploy local e em Sepolia via Foundry.
- Testes unitários concentrados no comportamento on-chain.

## Estrutura

```text
src/
  identity/IdentityRegistry.sol
  interfaces/IIdentityRegistry.sol
  token/PermissionedToken.sol
script/
  deploy/DeployCore.s.sol
test/
  unit/IdentityRegistry.t.sol
  unit/PermissionedToken.t.sol
utils/
  foundry/Vm.sol
```

## Pré-requisitos

- Foundry (`forge`, `cast`, `anvil`)
- Node.js + npm

Instalação do Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Instalação da dependência Solidity:

```bash
npm install
```

## Variáveis de ambiente

Use `.env.example` como base:

```bash
cp .env.example .env
```

Variáveis principais:

- `RPC_URL`: RPC local ou remoto
- `CHAIN_ID`: chain id alvo
- `PRIVATE_KEY`: chave do deployer
- `SEPOLIA_RPC_URL`: RPC da Sepolia
- `ETHERSCAN_API_KEY`: opcional para verificação

## Desenvolvimento local

Build:

```bash
npm run build
```

Testes:

```bash
npm test
```

Testes unitários:

```bash
npm run test:unit
```

## Deploy local

Terminal 1:

```bash
anvil --host 127.0.0.1 --port 8545 --chain-id 31337
```

Terminal 2:

```bash
cp .env.example .env
npm run deploy:local
```

O script grava os endereços em `deployments/<chainId>.json`.

## Deploy Sepolia

Preencha `SEPOLIA_RPC_URL`, `PRIVATE_KEY` e, se quiser verificação, `ETHERSCAN_API_KEY`.

```bash
npm run deploy:sepolia
```

## Decisões da limpeza

- O `README` anterior descrevia backend Java, frontend Next.js e scripts inexistentes neste repositório.
- A estrutura dos contratos foi separada por domínio (`identity`, `token`, `interfaces`).
- O contrato do token deixou de emitir um evento de debug que não era necessário para a regra de negócio.
- Os testes foram divididos por unidade de responsabilidade.
- A configuração agora ignora artefatos reais do Foundry e diretórios gerados em deploy.
