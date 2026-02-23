# Heartbeat Tasks

These tasks run automatically during heartbeat sessions. Execute them in order, skipping any that don't apply.

## Portfolio Health Check
- [ ] Check wallet balances for significant changes (>5% swing)
- [ ] Review open DeFi positions for liquidation risk
- [ ] Check token approval status for any unexpected approvals

## Market Monitoring
- [ ] Query prices for user's held tokens via CoinGecko
- [ ] Check if any held token has moved >10% since last heartbeat
- [ ] If significant move detected, prepare a brief summary for the user

## Maintenance
- [ ] Verify wallet connectivity (readiness check)
- [ ] Log heartbeat completion to memory with timestamp and any alerts
