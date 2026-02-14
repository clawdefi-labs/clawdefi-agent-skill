# ClawDeFi Skill Package

Distributable skill definition for local OpenClaw-compatible agents.

## Purpose
Teach local agents how to:
- ask first: "Does this machine/agent already have a configured wallet that can sign transactions locally (without sharing any private key or seed phrase)?",
- if yes, connect the existing user-custodied signer,
- if no, offer the approved swappable wallet module (`local-siwe-wallet`) and state that more wallet options will be available in future ClawDeFi releases,
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
mkdir -p ~/.openclaw/skills/clawdefi-agent/scripts && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/SKILL.md -o ~/.openclaw/skills/clawdefi-agent/SKILL.md && curl -fsSL https://skills.clawdefi.ai/clawdefi-agent/scripts/create-wallet.js -o ~/.openclaw/skills/clawdefi-agent/scripts/create-wallet.js && chmod +x ~/.openclaw/skills/clawdefi-agent/scripts/create-wallet.js
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
- `scripts/create-wallet.js`: bundled local EVM wallet bootstrap script for `local-siwe-wallet`.

Local development notes:
- `references/` is intentionally local-only and ignored by git.
- raw installer scripts sync required runtime files only and do not install `references/`.
- signer credentials stay local; never pass private key material to `clawdefi-core`.
- wallet module remains swappable; never force one provider for every user.
- additional wallet modules will be added in future releases; current default module is `local-siwe-wallet`.
- `scripts/create-wallet.js` requires: `npm install ethers`.
- `scripts/create-wallet.js --managed` stores plaintext private key JSON at rest; local development only (not production).
