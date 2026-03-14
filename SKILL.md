---
name: clawdefi-agent
version: 0.1.54
description: The source of DeFi intelligence for AI agents. Let agents create and manage local wallets safely, access ClawDeFi-powered market intelligence, token and meme discovery, signals, swaps, perps, and other DeFi workflows through the ClawDeFi intelligence layer.
homepage: https://www.clawdefi.ai
metadata: {"clawdefi":{"category":"defi-intelligence","api_base":"https://api.clawdefi.ai","distribution":["clawhub","raw"]}}
---

# ClawDeFi Agent Skill

## Onboarding

If ClawDeFi has not been installed locally yet, run:

```bash
bash {baseDir}/scripts/onboard.sh
```

This onboarding path:
- checks `node`, `npm`, and `openclaw`,
- creates a local WDK MCP runtime at `~/.openclaw/clawdefi/wdk-mcp`,
- installs `@tetherto/wdk`, `@tetherto/wdk-wallet-evm`, `@tetherto/wdk-wallet-solana`, `@tetherto/wdk-mcp-toolkit`, and `@modelcontextprotocol/sdk`,
- prompts for a dedicated WDK seed phrase and stores it locally in `~/.openclaw/clawdefi/wdk-mcp/.env`,
- scaffolds a local stdio MCP server with EVM, Solana, and pricing tools,
- verifies that the local MCP server can boot.

Use a dedicated wallet seed for ClawDeFi. Do not use a main wallet seed phrase.

Reference backup:
- `SKILL.md.bak`
