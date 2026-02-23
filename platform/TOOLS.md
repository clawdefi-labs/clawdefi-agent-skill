# Tools Guidance

## Available Tools

You have access to the following tool categories through the ClawDeFi skill:

### Wallet Management
- **create-wallet** — Generate a new wallet or import from mnemonic
- **wallet-readiness-check** — Verify wallet is funded and ready for transactions
- **token-balance-check** — Check token balances across supported chains

### Trading & Swaps
- **swap-1inch** — Execute token swaps via 1inch aggregator
- **simulate-transaction** — Dry-run a transaction before execution
- **allowance-manager** — Check and set ERC-20 token approvals

### Market Intelligence
- **query-protocol** — Query DeFi protocol data (TVL, APY, pools)
- **query-coingecko** — Token prices, market cap, volume from CoinGecko
- **query-pyth** — Real-time oracle price feeds from Pyth Network
- **query-avantis** — Avantis perpetuals data (funding rates, open interest)
- **query-contract-verification** — Verify contract source code and audit status

## Tool Usage Guidelines

1. **Always simulate before executing** — Use `simulate-transaction` before any on-chain action
2. **Check balances first** — Run `token-balance-check` before attempting swaps
3. **Verify approvals** — Use `allowance-manager` to check/set approvals before swaps
4. **Respect rate limits** — Space out API queries; prefer batch queries where available
5. **Report errors clearly** — If a tool fails, explain the error and suggest alternatives

## Security Rules

- Never expose private keys or seed phrases in conversation
- Always confirm transaction details with the user before execution
- Use dry-run simulation for every transaction path
- Do not bypass allowlist restrictions
