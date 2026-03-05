# ClawDeFi Skill Package

Distributable skill definition for local OpenClaw-compatible agents.

## Purpose
Teach local agents how to:
- first check MCP signer directory via `list_wallets`,
- if wallets exist, default to reusing signer-boundary wallet handles and ask only whether to create an additional wallet,
- if none exist and user asks to create now, create a signer-runtime generated wallet via MCP (`create_wallet`),
- capture user risk profile,
- query ClawDeFi MCP/API tools for contracts, ABIs, action specs, endpoint specs, and risk scores,
- perform permissionless DeFi actions (swap, perps, options, yield, and future modules) with guardrails,
- enforce disclaimer checks,
- handle emergency unwind routines,
- schedule periodic skill updates.

## Install Channels
This skill is designed to support two install methods.

1. ClawHub install (preferred)
```bash
npm i -g clawhub
clawhub install clawdefi-agent
```

2. Raw install (fallback)
```bash
bash scripts/install-raw.sh
```

Raw one-liner (manual style):
```bash
mkdir -p ~/.openclaw/skills/clawdefi-agent/scripts && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/SKILL.md -o ~/.openclaw/skills/clawdefi-agent/SKILL.md && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/token-balance-check.js -o ~/.openclaw/skills/clawdefi-agent/scripts/token-balance-check.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/allowance-manager.js -o ~/.openclaw/skills/clawdefi-agent/scripts/allowance-manager.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/simulate-transaction.js -o ~/.openclaw/skills/clawdefi-agent/scripts/simulate-transaction.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/swap-1inch.js -o ~/.openclaw/skills/clawdefi-agent/scripts/swap-1inch.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/query-protocol.js -o ~/.openclaw/skills/clawdefi-agent/scripts/query-protocol.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/query-coingecko.js -o ~/.openclaw/skills/clawdefi-agent/scripts/query-coingecko.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/query-avantis.js -o ~/.openclaw/skills/clawdefi-agent/scripts/query-avantis.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/query-pyth.js -o ~/.openclaw/skills/clawdefi-agent/scripts/query-pyth.js && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/query-contract-verification.js -o ~/.openclaw/skills/clawdefi-agent/scripts/query-contract-verification.js && chmod +x ~/.openclaw/skills/clawdefi-agent/scripts/token-balance-check.js ~/.openclaw/skills/clawdefi-agent/scripts/allowance-manager.js ~/.openclaw/skills/clawdefi-agent/scripts/simulate-transaction.js ~/.openclaw/skills/clawdefi-agent/scripts/swap-1inch.js ~/.openclaw/skills/clawdefi-agent/scripts/query-protocol.js ~/.openclaw/skills/clawdefi-agent/scripts/query-coingecko.js ~/.openclaw/skills/clawdefi-agent/scripts/query-avantis.js ~/.openclaw/skills/clawdefi-agent/scripts/query-pyth.js ~/.openclaw/skills/clawdefi-agent/scripts/query-contract-verification.js
```

## Update Channels
1. ClawHub update
```bash
clawhub update clawdefi-agent
```

2. Raw manifest update
```bash
bash scripts/update-from-manifest.sh
```

Cron example (every 6 hours):
```bash
0 */6 * * * /bin/bash /absolute/path/to/skill/scripts/update-from-manifest.sh >> /tmp/clawdefi-skill-update.log 2>&1
```

## Files
- `SKILL.md`: main behavioral and workflow instructions.
- `scripts/install-raw.sh`: raw installer script.
- `scripts/update-from-manifest.sh`: checksum-verified raw updater script.
- `scripts/token-balance-check.js`: bundled wallet balance checker for native and ERC20 assets.
- `scripts/allowance-manager.js`: bundled IERC20 allowance planner (safe exact-allowance default, revoke/unlimited with explicit policy).
- `scripts/simulate-transaction.js`: bundled pre-sign simulation module (`eth_call` + `estimateGas`) with revert decoding and slippage policy checks.
- `scripts/swap-1inch.js`: bundled 1inch-first swap module for quote/build/execute flows.
- `scripts/query-protocol.js`: bundled read-only protocol intelligence query module for `clawdefi-core`.
- `scripts/query-coingecko.js`: bundled CoinGecko market-data query module (simple price, token price, coin details, search).
- `scripts/query-avantis.js`: bundled Avantis connectivity + pair-feed query module for perp monitoring preflight.
- `scripts/query-pyth.js`: bundled Pyth oracle query module (Hermes latest/stream and Pyth Pro WSS endpoint guidance).
- `scripts/query-contract-verification.js`: bundled Etherscan contract verification query module (`getsourcecode`).

Local development notes:
- `references/` is intentionally local-only and ignored by git.
- raw installer scripts sync required runtime files only and do not install `references/`.
- signer credentials stay local; never pass private key material to `clawdefi-core`.
- wallet module remains swappable; never force one provider for every user.
- wallet provider labels are internal; user-facing replies should say "signer-runtime wallet" and avoid internal module IDs.
- `scripts/token-balance-check.js` requires: `npm install ethers` and local chain/query inputs (`RPC_URL`, `CHAIN_ID`, `WALLET_ADDRESS`, `TOKEN_ADDRESS`).
- `scripts/allowance-manager.js` requires: `npm install ethers` and token+spender context (`RPC_URL`, `CHAIN_ID`, `TOKEN_ADDRESS`, `SPENDER_ADDRESS`, owner wallet context).
- `scripts/simulate-transaction.js` requires: `npm install ethers` and transaction context (`RPC_URL`, `CHAIN_ID`, `TX_TO`, optional `TX_DATA`, sender context, and optional slippage bounds).
- `scripts/swap-1inch.js` requires: `npm install ethers`, `ONEINCH_API_KEY`, and swap context (`CHAIN_ID`, token pair, amount, sender/signer for execute mode, RPC for execute mode).
- `scripts/query-protocol.js` requires: reachable `CORE_API_BASE_URL` (default `http://127.0.0.1:8080`) and read query inputs (`slug`, `chainSlug`, action key by mode).
- `scripts/query-coingecko.js` requires: CoinGecko API access (`demo` or `pro` plan) and optional `COINGECKO_API_KEY` in local env.
- `scripts/query-avantis.js` requires: Avantis socket/core/feed endpoints reachable from local runtime (defaults provided; override via env/flags when needed).
- `scripts/query-pyth.js` requires: Pyth feed IDs for `latest`/`stream` mode and optional `PYTH_PRO_ACCESS_TOKEN` for pro endpoint auth metadata.
- `scripts/query-contract-verification.js` requires: user-managed `ETHERSCAN_API_KEY` in local env plus `CHAIN_ID` and `CONTRACT_ADDRESS`.
