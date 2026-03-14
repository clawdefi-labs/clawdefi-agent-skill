'use strict'

const fs = require('node:fs/promises')
const path = require('node:path')
const { createRequire } = require('node:module')
const { pathToFileURL } = require('node:url')

const STATE_DIR = process.env.OPENCLAW_STATE_DIR || path.join(process.env.HOME || '', '.openclaw')
const CLAWDEFI_DIR = path.join(STATE_DIR, 'clawdefi')
const MCP_DIR = path.join(CLAWDEFI_DIR, 'wdk-mcp')
const ENV_FILE = path.join(MCP_DIR, '.env')
const SELECTION_FILE = path.join(CLAWDEFI_DIR, 'wallet-selection.json')

const CHAIN_CONFIG = {
  ethereum: {
    family: 'evm',
    config: {
      provider: 'https://rpc.mevblocker.io/fast'
    }
  },
  base: {
    family: 'evm',
    config: {
      provider: 'https://mainnet.base.org'
    }
  },
  bsc: {
    family: 'evm',
    config: {
      provider: 'https://bsc-dataseed.binance.org'
    }
  },
  solana: {
    family: 'solana',
    config: {
      rpcUrl: 'https://api.mainnet-beta.solana.com',
      commitment: 'confirmed'
    }
  }
}

function printJson (payload) {
  process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`)
}

function fail (message, extra = {}) {
  printJson({
    ok: false,
    error: message,
    ...extra
  })
  process.exit(1)
}

function normalizeChain (value) {
  const chain = String(value || 'ethereum').toLowerCase()
  if (!CHAIN_CONFIG[chain]) {
    throw new Error(`Unsupported chain: ${chain}`)
  }
  return chain
}

function parseArgs (argv) {
  const args = {}
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i]
    if (!token.startsWith('--')) continue
    const key = token.slice(2)
    const next = argv[i + 1]
    if (!next || next.startsWith('--')) {
      args[key] = true
      continue
    }
    args[key] = next
    i += 1
  }
  return args
}

async function fileExists (filePath) {
  try {
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}

function decodeEnvValue (value) {
  const trimmed = value.trim()
  if (!trimmed) return ''
  if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
    return trimmed.slice(1, -1).replace(/'"'"'/g, "'")
  }
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.slice(1, -1)
  }
  return trimmed
}

async function readEnvMap () {
  if (!(await fileExists(ENV_FILE))) {
    return {}
  }

  const contents = await fs.readFile(ENV_FILE, 'utf8')
  const env = {}
  for (const rawLine of contents.split('\n')) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const index = line.indexOf('=')
    if (index === -1) continue
    const key = line.slice(0, index).trim()
    const value = line.slice(index + 1)
    env[key] = decodeEnvValue(value)
  }
  return env
}

function shellQuote (value) {
  return `'${String(value).replace(/'/g, `'"'"'`)}'`
}

async function writeEnvValue (key, value) {
  const lines = (await fileExists(ENV_FILE))
    ? (await fs.readFile(ENV_FILE, 'utf8')).split('\n')
    : []

  let replaced = false
  const nextLines = lines.map((line) => {
    if (line.startsWith(`${key}=`)) {
      replaced = true
      return `${key}=${shellQuote(value)}`
    }
    return line
  })

  if (!replaced) {
    nextLines.push(`${key}=${shellQuote(value)}`)
  }

  await fs.mkdir(path.dirname(ENV_FILE), { recursive: true })
  await fs.writeFile(ENV_FILE, `${nextLines.filter(Boolean).join('\n')}\n`, { mode: 0o600 })
}

async function ensureRuntimeReady () {
  if (!(await fileExists(path.join(MCP_DIR, 'package.json')))) {
    throw new Error(`WDK MCP runtime not found at ${MCP_DIR}. Run bash {baseDir}/scripts/onboard.sh first.`)
  }
}

function getRuntimeRequire () {
  return createRequire(path.join(MCP_DIR, 'package.json'))
}

async function importFromRuntime (specifier) {
  const runtimeRequire = getRuntimeRequire()
  const resolved = runtimeRequire.resolve(specifier)
  return import(pathToFileURL(resolved).href)
}

async function loadWalletModules () {
  await ensureRuntimeReady()
  const evmModule = await importFromRuntime('@tetherto/wdk-wallet-evm')
  const solanaModule = await importFromRuntime('@tetherto/wdk-wallet-solana')
  return {
    WalletManagerEvm: evmModule.default || evmModule.WalletManagerEvm,
    WalletManagerSolana: solanaModule.default || solanaModule.WalletManagerSolana
  }
}

async function requireSeed () {
  const env = await readEnvMap()
  const seed = env.WDK_SEED
  if (!seed) {
    throw new Error('No local wallet seed is configured. Create or import a wallet first.')
  }
  return seed
}

async function readSelection () {
  if (!(await fileExists(SELECTION_FILE))) {
    return { chain: 'ethereum', index: 0 }
  }
  const raw = JSON.parse(await fs.readFile(SELECTION_FILE, 'utf8'))
  return {
    chain: normalizeChain(raw.chain || 'ethereum'),
    index: Number(raw.index || 0)
  }
}

async function writeSelection (selection) {
  const next = {
    chain: normalizeChain(selection.chain),
    index: Number(selection.index || 0)
  }
  await fs.mkdir(path.dirname(SELECTION_FILE), { recursive: true })
  await fs.writeFile(SELECTION_FILE, `${JSON.stringify(next, null, 2)}\n`)
  return next
}

async function buildManager (chain, seed) {
  const normalizedChain = normalizeChain(chain)
  const { WalletManagerEvm, WalletManagerSolana } = await loadWalletModules()
  const chainConfig = CHAIN_CONFIG[normalizedChain]

  if (chainConfig.family === 'evm') {
    return new WalletManagerEvm(seed, chainConfig.config)
  }

  if (chainConfig.family === 'solana') {
    return new WalletManagerSolana(seed, chainConfig.config)
  }

  throw new Error(`Unsupported chain family for ${normalizedChain}`)
}

async function withAccount (chain, index, seed, callback) {
  const manager = await buildManager(chain, seed)
  try {
    const account = await manager.getAccount(index)
    return await callback({ manager, account })
  } finally {
    if (typeof manager.dispose === 'function') {
      manager.dispose()
    }
  }
}

async function deriveAddresses (seed, index = 0) {
  const addresses = {}
  for (const chain of Object.keys(CHAIN_CONFIG)) {
    addresses[chain] = await withAccount(chain, index, seed, async ({ account }) => account.getAddress())
  }
  return addresses
}

function getTokenList (args) {
  if (args.tokens) {
    return String(args.tokens)
      .split(',')
      .map((token) => token.trim())
      .filter(Boolean)
  }
  if (args.token) {
    return [String(args.token).trim()]
  }
  return []
}

function parseIndex (value, fallback = 0) {
  const parsed = value == null ? fallback : Number(value)
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`Invalid wallet index: ${value}`)
  }
  return parsed
}

function parseAmountBaseUnits (value) {
  if (value == null) {
    throw new Error('Missing required --amount in base units.')
  }
  if (!/^\d+$/.test(String(value))) {
    throw new Error('Amount must be an integer string in base units.')
  }
  return BigInt(String(value))
}

module.exports = {
  CHAIN_CONFIG,
  MCP_DIR,
  ENV_FILE,
  SELECTION_FILE,
  buildManager,
  deriveAddresses,
  fail,
  getTokenList,
  loadWalletModules,
  normalizeChain,
  parseAmountBaseUnits,
  parseArgs,
  parseIndex,
  printJson,
  readEnvMap,
  readSelection,
  requireSeed,
  withAccount,
  writeEnvValue,
  writeSelection
}
