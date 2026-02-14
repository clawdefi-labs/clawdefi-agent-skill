# ClawDeFi Skill Package

Distributable skill definition for local OpenClaw-compatible agents.

## Purpose
Teach local agents how to:
- ask first: "Do you already have a wallet that can sign transactions?",
- if yes, connect the existing user-custodied signer,
- if no, offer approved swappable wallet modules (`coinbase-agentkit-mcp-cdp-v2`, `coinbase-cdp-v2-direct-eoa`, `local-siwe-wallet`),
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
mkdir -p ~/.openclaw/skills/clawdefi-agent && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/SKILL.md -o ~/.openclaw/skills/clawdefi-agent/SKILL.md
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

Local development notes:
- `references/` is intentionally local-only and ignored by git.
- signer credentials stay local; never pass private key material to `clawdefi-core`.
- wallet module remains swappable; never force one provider for every user.
- CDP v1 is deprecated (effective February 2, 2026); use CDP Server Wallet v2 for all new integrations.
