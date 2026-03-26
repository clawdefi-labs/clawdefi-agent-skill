# ClawDeFi Skill Package

Distributable skill definition for local OpenClaw-compatible agents. Version **0.1.75**.

## Purpose
Teach local agents how to:
- Discover, create, import, and manage wallets via the WDK (Wallet Development Kit)
- Capture user risk profile and enforce disclaimer checks
- Query ClawDeFi MCP/API tools for contracts, ABIs, action specs, and risk scores
- Perform permissionless DeFi actions across multiple protocol categories with guardrails
- Enforce pre-sign simulation on all fund-impacting transactions
- Handle emergency unwind routines
- Schedule periodic skill updates

## Supported Protocol Modules

### Trading (Swaps)
Adapter: **0x Protocol** (primary), 1inch (legacy)
- `swap-common.js`, `swap-quote.js`, `swap-build.js`, `swap-simulate.js`, `swap-execute.js`
- `swap-action-helpers.js` — shared swap action utilities
- `disclaimer-common.js` — disclaimer status/register helpers used by swap and crosschain recovery
- `swap-1inch.js` — legacy 1inch swap module

### Perpetuals
Adapter: **Avantis** (Base)
- `perps-common.js`, `perps-market-context.js`, `perps-adapter-avantis.js`
- `perps-open-quote.js`, `perps-open-build.js`, `perps-open-simulate.js`, `perps-open-execute.js`
- `perps-close-quote.js`, `perps-close-build.js`, `perps-close-simulate.js`, `perps-close-execute.js`
- `perps-modify-position-build.js`, `perps-modify-position-simulate.js`, `perps-modify-position-execute.js`
- `perps-cancel-order-build.js`, `perps-cancel-order-simulate.js`, `perps-cancel-order-execute.js`
- `perps-risk-orders-build.js`, `perps-risk-orders-simulate.js`, `perps-risk-orders-execute.js`
- `perps-position-list.js`, `perps-pending-orders.js`
- `perps-referral-info.js`, `perps-referral-bind-build.js`, `perps-referral-bind-simulate.js`, `perps-referral-bind-execute.js`
- `perps-action-helpers.js`, `perps-tx-action-common.js`

### Lending
Adapter: **Aave V3**
- `lending-common.js`, `lending-adapter-aave.js`, `lending-markets.js`
- `lending-quote.js`, `lending-build.js`, `lending-simulate.js`, `lending-execute.js`
- `lending-action-helpers.js`

### Yield
Adapter: **Pendle**
- `yield-common.js`, `yield-adapter-pendle.js`, `yield-opportunities.js`
- `yield-quote.js`, `yield-build.js`, `yield-simulate.js`, `yield-execute.js`
- `yield-action-helpers.js`

### Options (Paused)
Adapter: **Thetanuts**
- `options-common.js`, `options-adapter-thetanuts.js`, `options-chain.js`
- `options-market-data.js`, `options-orderbook.js`, `options-positions.js`
- `options-quote.js`, `options-build.js`, `options-simulate.js`, `options-execute.js`
- `options-action-helpers.js`

### Predictions
Adapter: **Polymarket**
- `predictions-common.js`, `predictions-adapter-polymarket.js`, `predictions-markets.js`
- `predictions-quote.js`, `predictions-build.js`, `predictions-simulate.js`, `predictions-execute.js`
- `predictions-action-helpers.js`

### Market Intelligence
- `query-coingecko.js` — CoinGecko market data (price, rankings, search)
- `query-pyth.js` — Pyth oracle price feeds
- `query-pyth-stream-open.js`, `query-pyth-stream-poll.js`, `query-pyth-stream-close.js`, `query-pyth-stream-worker.js` — Pyth real-time streaming
- `crypto-market-rank.js` — market ranking utilities
- `market-intel-common.js` — shared market intel helpers
- `trading-signal.js` — trading signal generation
- `meme-rush.js` — meme token analytics

### Wallet (WDK)
- `wallet-common.js` — shared wallet utilities and chain config
- `wallet-discover.js` — discover existing wallets
- `wallet-create.js` — create new wallets
- `wallet-import.js` — import wallets from private keys
- `wallet-select.js` — select active wallet
- `wallet-balance.js` — check token balances
- `wallet-total-portfolio.js` — aggregate portfolio view
- `wallet-disclaimer-status.js` — read wallet disclaimer consent status
- `wallet-register-consent.js` — idempotent consent registration (explicit confirm flag required)
- `wallet-transfer.js` — token transfers
- `wallet-sign.js` — sign transactions
- `wallet-sign-broadcast.js` — sign and broadcast transactions
- `wallet-token-allowance-check.js` — check ERC-20 allowances
- `wallet-token-allowance-set.js` — set ERC-20 allowances

### Infrastructure
- `query-protocol.js` — protocol registry intelligence queries
- `query-chain-registry.js` — chain metadata registry
- `query-contract-verification.js` — Etherscan contract verification
- `query-address-info.js` — address metadata lookup
- `query-token-info.js` — token metadata lookup
- `query-token-audit.js` — token security audit checks
- `query-avantis.js` — Avantis connectivity and pair-feed queries
- `simulate-transaction.js` — pre-sign simulation (`eth_call` + `estimateGas`) with revert decoding

## Install Channels

1. ClawHub install (preferred)
```bash
npm i -g clawhub
clawhub install clawdefi-agent
```

2. Raw install (fallback)
```bash
bash scripts/install-raw.sh
```

3. Agent-guided install
```
Please fetch this first:
curl "https://www.clawdefi.ai/skill.md"

Then follow the installation steps in that file to install the skill.
```

## Update Channels

1. ClawHub update
```bash
clawhub update clawdefi-agent
```

2. Raw manifest update
```bash
bash scripts/update.sh
```

3. Legacy updater
```bash
bash scripts/update-from-manifest.sh
```

## Files
- `SKILL.md` — main behavioral and workflow instructions
- `manifest.json` — versioned file manifest with SHA-256 checksums
- `scripts/` — all runtime modules listed above
- `scripts/install-raw.sh` — raw installer script
- `scripts/install-platform.sh` — platform installer
- `scripts/update.sh` — portable skill updater
- `scripts/update-from-manifest.sh` — checksum-verified raw updater (legacy)
- `scripts/update-platform.sh` — platform updater
- `scripts/onboard.sh` — first-run onboarding script
- `scripts/generate-skill-manifest.sh` — manifest generation utility
- `scripts/generate-platform-manifest.sh` — platform manifest generation

## Local Development Notes
- `references/` is intentionally local-only and ignored by git
- Raw installer scripts sync required runtime files only and do not install `references/`
- Signer credentials stay local; never pass private key material to `clawdefi-core`
- Wallet module remains swappable; never force one provider for every user
- All fund-impacting actions require pre-sign simulation via `simulate-transaction.js`
- Avantis referral modules expose `clawdefiReferralRecipient` (defaults to `0x25Aa761B02C45D2B57bBb54Dd04D42772afdd291`; override via `CLAWDEFI_AVANTIS_REFERRER_ADDRESS`)
