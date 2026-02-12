# AlphaClaw Skill Package

Distributable skill definition for local OpenClaw-compatible agents.

## Purpose
Teach local agents how to:
- initialize a CDP signable smart wallet,
- capture user risk profile,
- query AlphaClaw MCP/API tools for contracts, ABIs, action specs, endpoint specs, and risk scores,
- perform permissionless DeFi actions (swap, perps, options, yield, and future modules) with guardrails,
- enforce disclaimer checks,
- handle emergency unwind routines,
- schedule periodic skill updates.

## Install Channels
This skill is designed to support two install methods.

1. ClawHub install (preferred)
```bash
npm i -g clawhub
clawhub install alphaclaw-agent
```

2. Raw install (fallback)
```bash
bash scripts/install-raw.sh
```

Raw one-liner (manual style):
```bash
mkdir -p ~/.openclaw/skills/alphaclaw-agent && curl -fsSL https://skills.alphaclaw.ai/alphaclaw-agent/SKILL.md -o ~/.openclaw/skills/alphaclaw-agent/SKILL.md
```

## Update Channels
1. ClawHub update
```bash
clawhub update alphaclaw-agent
```

2. Raw manifest update
```bash
bash scripts/update-from-manifest.sh
```

Cron example (every 6 hours):
```bash
0 */6 * * * /bin/bash /absolute/path/to/skill/scripts/update-from-manifest.sh >> /tmp/alphaclaw-skill-update.log 2>&1
```

## Files
- `SKILL.md`: main behavioral and workflow instructions.
- `scripts/install-raw.sh`: raw installer script.
- `scripts/update-from-manifest.sh`: checksum-verified raw updater script.

Local development notes:
- `references/` is intentionally local-only and ignored by git.
