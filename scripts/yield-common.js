'use strict'

const {
  chainToFamily,
  fail,
  parseArgs,
  parseIndex,
  printJson,
  readSelection,
  requireSeed,
  withAccount
} = require('./wallet-common.js')

const ADAPTERS = {
  pendle: () => require('./yield-adapter-pendle.js')
}

const PENDLE_CHAIN_ID_BY_SLUG = {
  'ethereum-mainnet': 1,
  'optimism-mainnet': 10,
  'bnb-smart-chain': 56,
  'arbitrum-one': 42161,
  'base-mainnet': 8453
}

const PENDLE_CHAIN_SLUG_BY_ID = Object.fromEntries(
  Object.entries(PENDLE_CHAIN_ID_BY_SLUG).map(([slug, chainId]) => [String(chainId), slug])
)

function normalizeAdapter (value) {
  const adapter = String(value || process.env.CLAWDEFI_YIELD_ADAPTER || 'pendle').trim().toLowerCase()
  if (!adapter) {
    throw new Error('Missing yield adapter.')
  }
  if (!Object.prototype.hasOwnProperty.call(ADAPTERS, adapter)) {
    throw new Error(`Unsupported yield adapter: ${adapter}`)
  }
  return adapter
}

function loadAdapter (value) {
  const adapter = normalizeAdapter(value)
  return {
    adapter,
    impl: ADAPTERS[adapter]()
  }
}

function normalizeChainForYield (value) {
  const parsed = String(value || '').trim().toLowerCase()
  if (!parsed) return ''
  if (parsed === 'eth' || parsed === 'ethereum' || parsed === 'mainnet') return 'ethereum-mainnet'
  if (parsed === 'op' || parsed === 'optimism') return 'optimism-mainnet'
  if (parsed === 'bsc' || parsed === 'bnb') return 'bnb-smart-chain'
  if (parsed === 'arb' || parsed === 'arbitrum') return 'arbitrum-one'
  if (parsed === 'base') return 'base-mainnet'
  return parsed
}

async function withWalletContext (args, intent, callback) {
  const seed = await requireSeed()
  const selection = await readSelection()
  const chain = normalizeChainForYield(args.chain || selection.chain || 'ethereum-mainnet')
  const index = parseIndex(args.index, selection.index)

  if (chainToFamily(chain) !== 'evm') {
    throw new Error(`Yield local execution currently supports EVM only. Received chain=${chain}.`)
  }

  return withAccount(chain, index, seed, async ({ account }) => {
    const address = await account.getAddress()
    return callback({
      account,
      address,
      chain,
      index,
      selection: {
        family: 'evm',
        chain,
        index
      }
    })
  }, { intent })
}

async function resolveWalletAddress (args) {
  if (args.address) {
    return String(args.address).trim()
  }
  const wallet = await withWalletContext(args, 'read', async ({ address }) => ({ address }))
  return wallet.address
}

function buildEnvelope ({ module, adapter, params, data = null, warnings = [], errors = [] }) {
  return {
    contractVersion: 'yield.local.v1',
    source: 'clawdefi-local-skill',
    module,
    adapter,
    params,
    data,
    warnings,
    errors
  }
}

function printSuccess (input) {
  printJson({
    ok: true,
    ...buildEnvelope(input)
  })
}

function printFailure (module, adapter, params, error, warnings = []) {
  fail(error.message, {
    ...buildEnvelope({
      module,
      adapter,
      params,
      data: null,
      warnings,
      errors: [
        {
          code: 'yield_action_failed',
          message: error.message
        }
      ]
    })
  })
}

module.exports = {
  PENDLE_CHAIN_ID_BY_SLUG,
  PENDLE_CHAIN_SLUG_BY_ID,
  loadAdapter,
  normalizeChainForYield,
  parseArgs,
  printFailure,
  printSuccess,
  readSelection,
  resolveWalletAddress
}

