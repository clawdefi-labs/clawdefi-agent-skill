---
name: alphaclaw-agent
version: 0.1.0
description: The source of DeFi intelligence for agents. Use this skill to initialize a CDP signable smart wallet, query permissionless DeFi actions (swap, perps, options, yield, and future modules), and retrieve protocol interaction specs, contracts, ABIs, endpoints, and risk scores.
homepage: https://www.alphaclaw.ai
metadata: {"alphaclaw":{"category":"defi-intelligence","api_base":"https://api.alphaclaw.ai","distribution":["clawhub","raw"]}}
---

# AlphaClaw Personal Skill

## 1) What AlphaClaw Is
AlphaClaw is the source of DeFi intelligence for agents.

It provides:
- Curated protocol intelligence: protocol intros, contract addresses, ABIs/interfaces, supported actions, and endpoint specs.
- Deterministic risk checks mapped to user profile (`beginner`, `advanced`, `expert`).
- Alerting for liquidation/exploit/policy events.
- Optional premium features gated by AlphaClaw staking entitlement.

Authority boundary:
- OpenClaw (or any LLM agent) orchestrates user requests.
- AlphaClaw Core (`alphaclaw-core`) is the source of truth for contracts, actions, risk policy, and execution constraints.

## 2) Install and Initialize a CDP Signable Smart Wallet (AgentKit)
Use this section first when wallet execution is required.

Prerequisites:
- Node.js 18+ (AgentKit docs) and npm.
- CDP API key from Coinbase Developer Portal.
- Use CDP wallet stack compatible with Server Wallet v2-era tooling.

Setup steps:
1. Create a project:
```bash
npm create onchain-agent@latest
```
2. For MCP-based AgentKit integration, install required packages:
```bash
npm install @coinbase/agentkit-model-context-protocol @coinbase/agentkit @modelcontextprotocol/sdk
```
3. Configure environment variables:
```bash
CDP_API_KEY_NAME=your_cdp_api_key_name
CDP_API_KEY_PRIVATE_KEY=your_cdp_api_key_private_key
```
4. Initialize AgentKit in code:
```ts
import { AgentKit } from "@coinbase/agentkit";

const agentKit = await AgentKit.from({
  cdpApiKeyName: process.env.CDP_API_KEY_NAME,
  cdpApiKeyPrivateKey: process.env.CDP_API_KEY_PRIVATE_KEY,
});
```

Execution policy:
- Do not execute DeFi actions until disclaimer acceptance is recorded.
- Route all protocol interaction planning through AlphaClaw MCP/API.
- Require deterministic risk approval before transaction build/sign flow.

## 3) Mandatory Runtime Workflow
1. Confirm wallet provider state (CDP AgentKit initialized and reachable).
2. Collect/confirm user risk profile: `beginner`, `advanced`, or `expert`.
3. Require explicit disclaimer acceptance.
4. Query AlphaClaw MCP tools for protocol metadata, action specs, contract/ABI references, endpoint specs, risk checks, and unwind path.
5. Present recommendation with expected yield band, key risks, safety warnings, and exact interaction path.
6. Require explicit user confirmation before transaction signing.

## 4) Required Disclaimer Text
Show this exact text before any strategy or transaction guidance:

> AlphaClaw provides analytics and agentic workflows, not financial advice.  
> DeFi carries risks including smart contract failure, oracle failure, and liquidation.  
> You are solely responsible for wallet custody and transaction signing.  
> Do you accept these risks and want to continue?

Rules:
- Do not proceed unless the user explicitly accepts.
- Log acceptance timestamp and disclaimer version for auditability.

## 5) Safety Policies
- Never bypass AlphaClaw risk engine results.
- Never suggest unsupported protocols or unknown contract addresses.
- Never invent ABIs, function signatures, or endpoints.
- Never ask for private keys or seed phrases.
- Always provide unwind path for leveraged or time-sensitive positions.

## 6) Update Policy
- Check AlphaClaw skill manifest every 6 hours.
- Apply only signed updates from trusted AlphaClaw publisher keys.
- Maintain rollback pointer to last known-good skill version.

## 7) Distribution Channels
Support both installation channels:

1. ClawHub channel:
- Install CLI if needed: `npm i -g clawhub`
- Install skill: `clawhub install alphaclaw-agent`
- Update skill later: `clawhub update alphaclaw-agent` or `clawhub update --all`

2. Raw URL channel:
- Install directly from hosted `SKILL.md`:
  - `bash scripts/install-raw.sh`
  - or manual one-liner:
    - `mkdir -p ~/.openclaw/skills/alphaclaw-agent && curl -fsSL https://skills.alphaclaw.ai/alphaclaw-agent/SKILL.md -o ~/.openclaw/skills/alphaclaw-agent/SKILL.md`
- Poll manifest and update with hash verification:
  - `bash scripts/update-from-manifest.sh`

Notes:
- Raw channel is for environments where ClawHub is not available.
- Raw updates must validate checksum and keep a rollback backup before overwrite.
