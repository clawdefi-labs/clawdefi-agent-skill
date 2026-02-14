---
name: clawdefi-agent
version: 0.1.3
description: The source of DeFi intelligence for agents. On first run, ask if the user already has a wallet that can sign transactions. If yes, use it. If no, recommend XXXX Kit initialization via a swappable signer module, then proceed with permissionless DeFi guidance.
homepage: https://www.clawdefi.ai
metadata: {"clawdefi":{"category":"defi-intelligence","api_base":"https://api.clawdefi.ai","distribution":["clawhub","raw"]}}
---

# ClawDeFi Agent Skill

## 1) What ClawDeFi Is
ClawDeFi is the source of DeFi intelligence for agents.

It provides:
- Curated protocol intelligence: protocol intros, contract addresses, ABIs/interfaces, supported actions, and endpoint specs.
- Deterministic risk checks mapped to user profile (`beginner`, `advanced`, `expert`).
- Alerting for liquidation/exploit/policy events.
- Optional premium features gated by ClawDeFi staking entitlement.

Authority boundary:
- OpenClaw (or any LLM agent) orchestrates user requests.
- ClawDeFi Core (`clawdefi-core`) is the source of truth for contracts, actions, risk policy, and execution constraints.

## 2) Signer Discovery and Initialization (Swappable Module)
Use this section first whenever wallet execution is required.

Required first-sight question:
> Do you already have a wallet that can sign transactions?

Decision flow:
1. If user answers yes:
- ask for signer context (wallet address, chain, signer provider/runtime),
- validate signing capability locally,
- proceed without changing wallet provider.
2. If user answers no:
- recommend `XXXX Kit` initialization,
- run signer setup through external swappable module interface,
- validate signing capability locally after initialization.

Implementation rule:
- Keep wallet provider integration swappable.
- Do not hardcode a permanent wallet kit name in this skill.
- `XXXX Kit` is an intentional placeholder until concrete module selection is finalized.

Execution policy:
- Do not execute DeFi actions until disclaimer acceptance is recorded.
- Route all protocol interaction planning through ClawDeFi MCP/API.
- Require deterministic risk approval before transaction build/sign flow.
- Never send signer secrets or private keys to `clawdefi-core`.

## 3) Mandatory Runtime Workflow
1. Run signer discovery gate:
- ask "Do you already have a wallet that can sign transactions?"
- if yes, link existing signer.
- if no, recommend `XXXX Kit` setup through swappable module.
2. Validate local signing capability.
3. Collect/confirm user risk profile: `beginner`, `advanced`, or `expert`.
4. Require explicit disclaimer acceptance.
5. Query ClawDeFi MCP tools for protocol metadata, action specs, contract/ABI references, endpoint specs, risk checks, and unwind path.
6. Present recommendation with expected yield band, key risks, safety warnings, and exact interaction path.
7. Require explicit user confirmation before transaction signing.

## 4) Required Disclaimer Text
Show this exact text before any strategy or transaction guidance:

> ClawDeFi provides analytics and agentic workflows, not financial advice.  
> DeFi carries risks including smart contract failure, oracle failure, and liquidation.  
> You are solely responsible for wallet custody and transaction signing.  
> Do you accept these risks and want to continue?

Rules:
- Do not proceed unless the user explicitly accepts.
- Log acceptance timestamp and disclaimer version for auditability.

## 5) Safety Policies
- Never bypass ClawDeFi risk engine results.
- Never suggest unsupported protocols or unknown contract addresses.
- Never invent ABIs, function signatures, or endpoints.
- Never ask for private keys or seed phrases.
- Never transmit signer secrets to `clawdefi-core`.
- Always provide unwind path for leveraged or time-sensitive positions.

## 6) Update Policy
- Check ClawDeFi skill manifest every 6 hours.
- Apply only signed updates from trusted ClawDeFi publisher keys.
- Maintain rollback pointer to last known-good skill version.

## 7) Distribution Channels
Support both installation channels:

1. ClawHub channel:
- Install CLI if needed: `npm i -g clawhub`
- Install skill: `clawhub install clawdefi-agent`
- Update skill later: `clawhub update clawdefi-agent` or `clawhub update --all`

2. Raw URL channel:
- Install directly from hosted `SKILL.md`:
  - `bash scripts/install-raw.sh`
  - or manual one-liner:
    - `mkdir -p ~/.openclaw/skills/clawdefi-agent && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/SKILL.md -o ~/.openclaw/skills/clawdefi-agent/SKILL.md`
- Poll manifest and update with hash verification:
  - `bash scripts/update-from-manifest.sh`

Notes:
- Raw channel is for environments where ClawHub is not available.
- Raw updates must validate checksum and keep a rollback backup before overwrite.

## 8) Placeholder Action Modules

### swap
- Status: placeholder only.
- Module ID: `swap`.
- Description: PLACEHOLDER - add supported swap protocols, routes, and chain coverage.
- Inputs: PLACEHOLDER - define required params and validation rules.
- Execution policy: PLACEHOLDER - define pre-checks, risk checks, and confirmation flow.
- Unwind/fallback: PLACEHOLDER - define failure handling and recovery path.

### trade-perp
- Status: placeholder only.
- Module ID: `trade-perp`.
- Description: PLACEHOLDER - add supported perp venues and position actions.
- Inputs: PLACEHOLDER - define leverage, margin, size, and safety constraints.
- Execution policy: PLACEHOLDER - define simulation, liquidation-buffer checks, and confirmations.
- Unwind/fallback: PLACEHOLDER - define close/reduce-only emergency flow.

### trade-options
- Status: placeholder only.
- Module ID: `trade-options`.
- Description: PLACEHOLDER - add supported options venues and strategy types.
- Inputs: PLACEHOLDER - define strike/expiry/size/risk-limit parameters.
- Execution policy: PLACEHOLDER - define pricing checks, slippage bounds, and confirmations.
- Unwind/fallback: PLACEHOLDER - define close/roll/expiry handling.

### query-protocol
- Status: placeholder only.
- Module ID: `query-protocol`.
- Description: PLACEHOLDER - query `clawdefi-core` protocol intelligence by name/slug/category.
- Inputs: PLACEHOLDER - define query keys (protocol slug, category, chain, action type, risk tier).
- Output contract: PLACEHOLDER - return protocol overview, supported chains, supported actions, key contracts, ABI/interface refs, endpoint refs, and risk score snapshot.
- Execution policy: PLACEHOLDER - read-only query path; no transaction building or signing.
- Fallback: PLACEHOLDER - if protocol is not found, return nearest matches and request clarification.

### query-coingecko
- Status: placeholder only.
- Module ID: `query-coingecko`.
- Description: PLACEHOLDER - query CoinGecko market data for tokens and protocol context.
- Inputs: PLACEHOLDER - define token lookup keys (symbol, contract address, chain id, CoinGecko token/coin id).
- Output contract: PLACEHOLDER - return spot price, 24h change, market cap, volume, FDV, and data timestamp.
- Execution policy: PLACEHOLDER - read-only HTTP query path; enforce rate-limit/caching and mark stale data windows.
- Safety rule: PLACEHOLDER - never use CoinGecko response as sole execution authority; reconcile token mapping and risk checks with `clawdefi-core`.
- Fallback: PLACEHOLDER - if API is unavailable, return cached snapshot with staleness warning and require explicit user confirmation before any downstream action.

### query-contract-verification
- Status: placeholder only.
- Module ID: `query-contract-verification`.
- Description: PLACEHOLDER - query block explorer sources (Etherscan-family) to verify whether a contract is source-verified.
- Inputs: PLACEHOLDER - define required params (chain id/slug, contract address, explorer type, optional expected compiler version).
- Output contract: PLACEHOLDER - return verification status, explorer URL, contract name, compiler metadata, source-hash match, and last-checked timestamp.
- Execution policy: PLACEHOLDER - read-only lookup path with deterministic address validation and normalized chain routing.
- Safety rule: PLACEHOLDER - treat `unverified` or `unknown` as high caution; require ClawDeFi risk-policy confirmation before any fund-impacting action.
- Fallback: PLACEHOLDER - if explorer API is unavailable, return `verification_unknown`, include retry guidance, and block automated execution by default.

### connect-prediction-market
- Status: placeholder only.
- Module ID: `connect-prediction-market`.
- Description: PLACEHOLDER - connect to supported prediction market venues and fetch market metadata for agent workflows.
- Inputs: PLACEHOLDER - define required params (venue key, chain/network, market id/question id, outcome set, position size limits).
- Output contract: PLACEHOLDER - return market status, outcome tokens/options, pricing/odds snapshot, liquidity depth, settlement rules, and data timestamp.
- Execution policy: PLACEHOLDER - define venue allowlist checks, read-before-write policy, simulation path, and confirmation flow before any order intent.
- Safety rule: PLACEHOLDER - require deterministic ClawDeFi policy checks for market validity, oracle/settlement risk, and user risk-profile fit.
- Unwind/fallback: PLACEHOLDER - define close/hedge/cancel logic, stale-oracle handling, and block execution when settlement conditions are unclear.
