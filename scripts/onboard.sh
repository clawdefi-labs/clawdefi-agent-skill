#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
CLAWDEFI_DIR="${STATE_DIR}/clawdefi"
MCP_DIR="${CLAWDEFI_DIR}/wdk-mcp"
ENV_FILE="${MCP_DIR}/.env"
PACKAGE_FILE="${MCP_DIR}/package.json"
INDEX_FILE="${MCP_DIR}/index.mjs"
RUN_FILE="${MCP_DIR}/run.sh"

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required binary not found: $1" >&2
    exit 1
  fi
}

check_node_version() {
  local major
  major="$(node -p "process.versions.node.split('.')[0]")"
  if [ "$major" -lt 20 ]; then
    echo "ERROR: Node.js 20+ is required. Found: $(node -v)" >&2
    exit 1
  fi
}

prompt_seed() {
  if [ -n "${WDK_SEED:-}" ]; then
    printf '%s' "$WDK_SEED"
    return 0
  fi

  if [ -f "$ENV_FILE" ] && grep -q '^WDK_SEED=' "$ENV_FILE"; then
    sed -n 's/^WDK_SEED=//p' "$ENV_FILE"
    return 0
  fi

  local seed
  printf 'Enter a dedicated WDK seed phrase (12 or 24 words): ' >&2
  stty -echo
  IFS= read -r seed
  stty echo
  printf '\n' >&2

  if [ -z "$seed" ]; then
    echo "ERROR: seed phrase is required." >&2
    exit 1
  fi

  local words
  words="$(printf '%s' "$seed" | awk '{print NF}')"
  if [ "$words" -ne 12 ] && [ "$words" -ne 24 ]; then
    echo "ERROR: seed phrase must be 12 or 24 words." >&2
    exit 1
  fi

  printf '%s' "$seed"
}

write_package_json() {
  cat >"$PACKAGE_FILE" <<'EOF'
{
  "name": "clawdefi-wdk-mcp",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node index.mjs"
  }
}
EOF
}

write_index() {
  cat >"$INDEX_FILE" <<'EOF'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  INDEXER_TOOLS,
  PRICING_TOOLS,
  WALLET_TOOLS,
  WdkMcpServer
} from '@tetherto/wdk-mcp-toolkit'
import WalletManagerEvm from '@tetherto/wdk-wallet-evm'
import WalletManagerSolana from '@tetherto/wdk-wallet-solana'

const requiredEnv = ['WDK_SEED']
for (const key of requiredEnv) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`)
    process.exit(1)
  }
}

const server = new WdkMcpServer('clawdefi-wdk-mcp', '0.1.0')
  .useWdk({ seed: process.env.WDK_SEED })
  .registerWallet('ethereum', WalletManagerEvm, {
    provider: process.env.CLAWDEFI_EVM_RPC_URL || 'https://rpc.mevblocker.io/fast'
  })
  .registerWallet('base', WalletManagerEvm, {
    provider: process.env.CLAWDEFI_BASE_RPC_URL || 'https://mainnet.base.org'
  })
  .registerWallet('bsc', WalletManagerEvm, {
    provider: process.env.CLAWDEFI_BSC_RPC_URL || 'https://bsc-dataseed.binance.org'
  })
  .registerWallet('solana', WalletManagerSolana, {
    rpcUrl: process.env.CLAWDEFI_SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
    commitment: 'confirmed'
  })
  .usePricing()

const tools = [
  ...WALLET_TOOLS,
  ...PRICING_TOOLS
]

if (process.env.WDK_INDEXER_API_KEY) {
  server.useIndexer({ apiKey: process.env.WDK_INDEXER_API_KEY })
  tools.push(...INDEXER_TOOLS)
}

server.registerTools(tools)

const transport = new StdioServerTransport()
await server.connect(transport)

console.error('ClawDeFi WDK MCP server running on stdio')
console.error('Registered chains:', server.getChains())
EOF
}

write_env() {
  local seed="$1"
  umask 077
  {
    printf 'WDK_SEED=%q\n' "$seed"
    cat <<'EOF'
CLAWDEFI_EVM_RPC_URL=https://rpc.mevblocker.io/fast
CLAWDEFI_BASE_RPC_URL=https://mainnet.base.org
CLAWDEFI_BSC_RPC_URL=https://bsc-dataseed.binance.org
CLAWDEFI_SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
# Optional:
# WDK_INDEXER_API_KEY=
EOF
  } >"$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

write_runner() {
  cat >"$RUN_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
set -a
. "$DIR/.env"
set +a

exec npm --prefix "$DIR" run start --silent
EOF
  chmod +x "$RUN_FILE"
}

install_dependencies() {
  npm --prefix "$MCP_DIR" install \
    @modelcontextprotocol/sdk \
    @tetherto/wdk \
    @tetherto/wdk-mcp-toolkit \
    @tetherto/wdk-wallet-evm \
    @tetherto/wdk-wallet-solana
}

boot_check() {
  (
    set -a
    . "$ENV_FILE"
    set +a
    cd "$MCP_DIR"
    node index.mjs >/dev/null 2>&1 &
    local pid=$!
    sleep 2
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      wait "$pid"
      return 1
    fi
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" 2>/dev/null || true
  )
}

main() {
  require_bin node
  require_bin npm
  require_bin openclaw
  check_node_version

  mkdir -p "$MCP_DIR"

  local seed
  seed="$(prompt_seed)"

  write_package_json
  write_index
  write_env "$seed"
  write_runner

  install_dependencies

  if ! boot_check; then
    echo "ERROR: local WDK MCP boot check failed." >&2
    exit 1
  fi

  cat <<EOF
ClawDeFi onboarding completed.

Local runtime:
  $MCP_DIR

Local launcher:
  $RUN_FILE

Next step:
  point your local MCP client at: $RUN_FILE
EOF
}

main "$@"
