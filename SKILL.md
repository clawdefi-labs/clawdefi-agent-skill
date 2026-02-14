---
name: clawdefi-agent
version: 0.1.14
description: The source of DeFi intelligence for agents. On first run, ask whether this machine/agent already has a configured wallet that can sign transactions locally (without sharing any private key or seed phrase). If yes, use it. If no, offer the approved local SIWE wallet module, explicitly state more wallet options will be available in future releases, validate readiness, then proceed with permissionless DeFi guidance.
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

Required first-sight question (exact text, no paraphrase):
> Does this machine/agent already have a configured wallet that can sign transactions locally (without sharing any private key or seed phrase)?

Decision flow:
1. If user answers yes:
- ask for signer context (wallet address, chain, signer provider/runtime),
- validate signing capability locally,
- proceed without changing wallet provider.
2. If user answers no:
- present this exact wallet option list in this exact order:
  1. `local-siwe-wallet`
- state this exact line after showing the option list:
  - `More wallet options will be available in future ClawDeFi releases.`
- include pros, cons, requirements, and credential-source notes from this section for each option,
- let user select one,
- run setup through swappable module interface,
- validate module readiness locally after initialization.

Credential custody and prompt policy (must be stated before setup):
- Wallet credentials/secrets are stored locally on the user-controlled machine/agent runtime.
- ClawDeFi never asks for private keys, seed phrases, or raw credential secrets.
- ClawDeFi does not custody wallet credentials.
- If future provider-based modules require credentials, instruct users to create them at provider dashboards and keep them in local env/secret storage only.
- Never ask users to paste credential values into chat.

### Approved Wallet Module Choices

#### option-a: local-siwe-wallet
Best for:
- lightweight local wallet bootstrap and SIWE-based auth/signing flow with no external wallet provider dependency.

Pros:
- fully local signer control (non-custodial, no third-party wallet API credential required),
- fastest bootstrap path for local OpenClaw agents.

Cons:
- user/operator is fully responsible for key backup, rotation, and endpoint reliability,
- insecure local key handling can still lead to loss.

Requirements:
- Node.js runtime in the skill environment,
- dependency: `npm install ethers`,
- bundled scripts: `scripts/create-wallet.js`, `scripts/wallet-readiness-check.js`, and `scripts/allowance-manager.js`,
- local secure env or secret-storage path for signer variables,
- selected-chain RPC endpoint for balance/readiness checks.

Credential source:
- no external provider credential required,
- signer credentials are generated locally via bundled script on this machine.

Setup:
- Install dependency once in the skill runtime environment:
  - `npm install ethers`
- Create wallet in env-output mode using bundled script:
  - `node scripts/create-wallet.js --env`
- Persist `WALLET_ADDRESS` and `PRIVATE_KEY` in secure local environment storage.
- Build SIWE message (domain/URI, address, chain ID, nonce, issued-at timestamp) and sign with local key.

Readiness checks:
- run bundled readiness module:
  - `node scripts/wallet-readiness-check.js --json`
- recover signer from SIWE signature and match expected address,
- selected-chain RPC balance query succeeds,
- nonce query succeeds on selected chain,
- controlled transaction simulation succeeds before live execution.

Security guard:
- never print private key or seed in logs (the `--env` mode prints it to stdout intentionally; treat stdout as secret and do not run in CI or log-captured environments),
- never transmit signer secrets to external services.
- `--managed` file mode stores plaintext private key JSON at rest and is local-development only (not production).

#### future-wallet-modules
- Status: not yet available.
- Rule: do not present wallet modules not listed in this skill release.
- Required line to show users when they need alternatives:
  - `More wallet options will be available in future ClawDeFi releases.`

Implementation rule:
- Keep wallet provider integration swappable.
- Do not hardcode a single mandatory wallet provider for all users.
- Wallet module selection must stay user-consented, replaceable, and least-privilege.

Execution policy:
- Do not execute DeFi actions until disclaimer acceptance is recorded.
- Route all protocol interaction planning through ClawDeFi MCP/API.
- Require deterministic risk approval before transaction build/sign flow.
- Never send signer secrets or private keys to `clawdefi-core`.

## 3) Mandatory Runtime Workflow
1. Run signer discovery gate:
- ask "Does this machine/agent already have a configured wallet that can sign transactions locally (without sharing any private key or seed phrase)?"
- if yes, link existing signer.
- if no, present wallet options in exact order, include pros/cons/requirements/credential-source notes, explicitly state that more wallet options will be available in future ClawDeFi releases, then run selected setup (`local-siwe-wallet`).
2. Run `wallet-readiness-check` (chain, balance, nonce, RPC health, signature roundtrip).
  - recommended command: `node scripts/wallet-readiness-check.js --json`
3. Run `query-chain-registry` for canonical chain/RPC/explorer context.
4. Collect/confirm user risk profile: `beginner`, `advanced`, or `expert`.
5. Require explicit disclaimer acceptance.
6. Run `query-action-spec` to fetch canonical action contract from `clawdefi-core`.
7. Run `query-integration-endpoint` to fetch official endpoint/method/auth/rate-limit guidance.
8. Run `simulate-transaction` before any sign request.
9. When action requires ERC20 approvals, run `allowance-manager` before tx build/sign.
10. Run `build-unwind-plan` and show fallback path before execution confirmation.
11. Run `subscribe-alerts` (poll-mode MVP), then use `poll-alert-events` and `close-alert-subscription` as needed.
12. Present recommendation with expected yield band, key risks, safety warnings, and exact interaction path.
13. Require explicit user confirmation before transaction signing.

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
- Never ask users to paste API secrets or wallet credentials into chat.
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
- Install directly from hosted raw artifacts (`SKILL.md` + required runtime script):
  - `bash scripts/install-raw.sh`
  - or manual one-liner:
    - `mkdir -p ~/.openclaw/skills/clawdefi-agent/scripts && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/SKILL.md -o ~/.openclaw/skills/clawdefi-agent/SKILL.md && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/create-wallet.js -o ~/.openclaw/skills/clawdefi-agent/scripts/create-wallet.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/wallet-readiness-check.js -o ~/.openclaw/skills/clawdefi-agent/scripts/wallet-readiness-check.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/allowance-manager.js -o ~/.openclaw/skills/clawdefi-agent/scripts/allowance-manager.js && chmod +x ~/.openclaw/skills/clawdefi-agent/scripts/create-wallet.js ~/.openclaw/skills/clawdefi-agent/scripts/wallet-readiness-check.js ~/.openclaw/skills/clawdefi-agent/scripts/allowance-manager.js`
- Poll manifest and update with hash verification:
  - `bash scripts/update-from-manifest.sh`

Notes:
- Raw channel is for environments where ClawHub is not available.
- Raw updates keep rollback backups before overwrite and sync required runtime script files.
- `references/` is local-only and is intentionally not installed by raw installer scripts.

## 8) Placeholder Action Modules

### query-chain-registry
- Priority: P0.
- Status: placeholder only.
- Module ID: `query-chain-registry`.
- Purpose: resolve canonical chain metadata and trusted RPC/explorer registry data before execution planning.
- Inputs: `chainSlug` or `chainId` (optional: `intent` = `read` | `simulate` | `broadcast`).
- Output contract: canonical `chainId`, `chainSlug`, `nativeSymbol`, `explorerUrls`, prioritized RPC list with trust/health metadata.
- Execution policy: read-only path via `clawdefi-core` (DB-backed); no free-form external chain lookup.
- Safety rule: reject unknown chains or untrusted RPC endpoints (fail closed).
- Fallback: return `chain_unavailable` and block execution actions until resolved.

### query-action-spec
- Priority: P0.
- Status: active in MVP.
- Module ID: `query-action-spec`.
- Purpose: fetch canonical required params/functions/prechecks for a target action.
- MCP mapping: `POST /tools/get_action_spec`.
- Required input: `protocolSlug`, `chainSlug`, `actionKey`.
- Output contract: action metadata, required functions (with contract context), required endpoints, unwind plan.
- Safety rule: block execution planning when action spec is missing.

### query-integration-endpoint
- Priority: P0.
- Status: active in MVP.
- Module ID: `query-integration-endpoint`.
- Purpose: fetch official endpoint/method/auth/rate-limit contract for an action.
- MCP mapping: `POST /tools/get_integration_endpoint`.
- Required input: `protocolSlug`, `chainSlug`, `actionKey` (optional: `serviceName`, `endpointKey`).
- Output contract: filtered required endpoint list for deterministic integration.
- Safety rule: never allow ad-hoc endpoint URLs outside curated response.

### build-unwind-plan
- Priority: P0.
- Status: active in MVP (position-aware when snapshot exists, curated fallback otherwise).
- Module ID: `build-unwind-plan`.
- Purpose: return deterministic unwind steps plus emergency fallback path.
- MCP mapping: `POST /tools/build_unwind_plan`.
- Required input: `protocolSlug`, `chainSlug`, `actionKey` (optional: `positionId`).
- Output contract:
  - returns `position_aware` plan when a matching snapshot exists,
  - returns `curated_fallback` when snapshot is missing/stale-hard,
  - includes confidence, abort conditions, warnings, and metadata.
- Safety rule: require user confirmation and live-state revalidation before unwind execution.

### subscribe-alerts
- Priority: P0.
- Status: active in MVP (poll mode).
- Module ID: `subscribe-alerts`.
- Purpose: register liquidation/exploit/policy alert expectations plus heartbeat assumptions.
- MCP mapping: `POST /tools/subscribe_alerts`.
- Current behavior:
  - returns `subscriptionId`, `mode=poll`, polling cadence, expiry, and `nextCursor`.
  - use cursor-based polling for new events.
- Agent rule: do not claim WebSocket/SSE streaming in MVP.

### poll-alert-events
- Priority: P0.
- Status: active in MVP (poll mode).
- Module ID: `poll-alert-events`.
- Purpose: fetch incremental alert events for a subscription using signed cursor.
- MCP mapping: `POST /tools/poll_alert_events`.
- Required input: `subscriptionId`, `wallet` (optional: `cursor`, `limit`).
- Output contract: event list + updated `nextCursor`.
- Safety rule: handle `cursor_replay` and `cursor_out_of_sync` as hard sync errors.

### close-alert-subscription
- Priority: P0.
- Status: active in MVP.
- Module ID: `close-alert-subscription`.
- Purpose: close a poll subscription when no longer needed.
- MCP mapping: `POST /tools/close_alert_subscription`.
- Required input: `subscriptionId`, `wallet`.
- Output contract: close result with `closed=true`.

### simulate-transaction
- Priority: P0.
- Status: placeholder (required before production execution).
- Module ID: `simulate-transaction`.
- Purpose: mandatory pre-sign simulation with revert decoding and slippage/risk checks.
- Inputs: PLACEHOLDER - define call target, calldata, value, signer, chain, and slippage bounds.
- Execution policy: PLACEHOLDER - run simulation before any sign prompt; block on revert/high-risk outcomes.
- Output contract: PLACEHOLDER - simulation pass/fail, decoded revert reason, computed slippage and risk warnings.

### wallet-readiness-check
- Priority: P0.
- Status: active in MVP (implemented as local bundled module).
- Module ID: `wallet-readiness-check`.
- Purpose: verify signer health before any DeFi action.
- Implementation path: `scripts/wallet-readiness-check.js`.
- Required inputs:
  - `RPC_URL` (or `CHAIN_RPC_URL` / `ETH_RPC_URL`) or `--rpc-url`,
  - `CHAIN_ID` or `--chain-id`,
  - `PRIVATE_KEY` or `--private-key`,
  - optional `WALLET_ADDRESS` or `--wallet-address` (must match derived signer),
  - optional `MIN_NATIVE_BALANCE_WEI` / `--min-native-balance-wei`.
- Standard run command:
  - `node scripts/wallet-readiness-check.js --json`
- Output contract:
  - `ok` boolean,
  - `walletAddress`, `chainId`, `rpcUrl`,
  - checks: `rpcHealthy`, `chainSelected`, `chainMatchesExpected`, `balanceSane`, `nonceReadable`, `signatureRoundtrip`,
  - metrics: `balanceWei`, `balanceEth`, `nonce`, `minNativeBalanceWei`.
- Failure policy: fail closed; do not proceed to action planning/sign prompt until readiness passes with `ok=true`.

### quote-and-route-swap
- Priority: P1.
- Status: placeholder only.
- Module ID: `quote-and-route-swap`.
- Description: PLACEHOLDER - route and quote swaps with guardrails (`maxSlippage`, `minLiquidity`, route-risk constraints).
- Inputs: PLACEHOLDER - define token pair, amount, side (`exactIn`/`exactOut`), chain, slippage cap, allowlist scope.
- Output contract: PLACEHOLDER - candidate routes, quoted outputs, price impact, liquidity depth, and selected best route rationale.
- Execution policy: PLACEHOLDER - require route allowlist + prechecks + simulation before sign prompt.
- Safety rule: PLACEHOLDER - block when liquidity is below threshold or route risk exceeds policy.
- Fallback: PLACEHOLDER - return no-safe-route result and request user adjustment.

### allowance-manager
- Priority: P1.
- Status: active in MVP (local planning module).
- Module ID: `allowance-manager`.
- Purpose: check current ERC20 allowance and build deterministic approval/revoke transaction plan.
- Implementation path: `scripts/allowance-manager.js` (IERC20 ABI-based: `allowance`, `approve`, optional `symbol` and `decimals`).
- Required inputs:
  - `RPC_URL` (or `CHAIN_RPC_URL` / `ETH_RPC_URL`) or `--rpc-url`,
  - `CHAIN_ID` or `--chain-id`,
  - `TOKEN_ADDRESS` or `--token-address`,
  - `SPENDER_ADDRESS` or `--spender-address`,
  - owner context via `WALLET_ADDRESS`/`--owner-address` or `PRIVATE_KEY`/`--private-key` (owner can be derived from private key),
  - for exact mode: `DESIRED_AMOUNT_WEI` or `--desired-amount-wei`.
- Supported modes:
  - `exact` (default, safest),
  - `revoke`,
  - `unlimited` (requires explicit `--allow-unlimited`).
- Standard run command:
  - `node scripts/allowance-manager.js --mode exact --token-address <token> --spender-address <spender> --desired-amount-wei <wei> --json`
- Output contract:
  - `policy`, token/owner/spender/chain context,
  - allowance state (`currentWei`, `targetWei`, `deltaWei`, `action`),
  - deterministic approval steps with encoded calldata (`steps[]`),
  - warning set (including unlimited and reset-first cautions).
- Execution policy:
  - exact allowance by default,
  - unlimited allowance requires explicit user opt-in,
  - module is planning only and does not broadcast transactions.
- Safety rule:
  - enforce spender allowlist from `query-action-spec` before execution,
  - reject unknown token/spender addresses (fail closed).
- Fallback:
  - if allowance cannot be queried, return failure and block execution until RPC/token state is healthy.

### position-health-check
- Priority: P1.
- Status: placeholder only.
- Module ID: `position-health-check`.
- Description: PLACEHOLDER - check exposure/LTV/liquidation distance before and after planned actions.
- Inputs: PLACEHOLDER - protocol, position id(s), account, market params, projected action deltas.
- Output contract: PLACEHOLDER - current health metrics, projected post-action metrics, threshold breaches, and warning set.
- Execution policy: PLACEHOLDER - run pre-action and post-action checks as deterministic gates.
- Safety rule: PLACEHOLDER - block when projected liquidation distance or health factor violates policy.
- Fallback: PLACEHOLDER - return safer alternatives (reduce size/deleverage/partial unwind).

### contract-trust-check
- Priority: P1.
- Status: placeholder only.
- Module ID: `contract-trust-check`.
- Description: PLACEHOLDER - combine verification status, allowlist status, and risk snapshot into one trust verdict.
- Inputs: PLACEHOLDER - chain, contract address, protocol context, expected contract role.
- Output contract: PLACEHOLDER - verdict (`allow`/`warn`/`deny`) with evidence fields and timestamps.
- Execution policy: PLACEHOLDER - read-only checks against curated registry and verification sources.
- Safety rule: PLACEHOLDER - deny by default for unknown or unverified contracts unless explicitly overridden by policy.
- Fallback: PLACEHOLDER - return `trust_unknown` and block automated execution.

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
