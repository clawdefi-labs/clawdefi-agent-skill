'use strict'

const {
  deriveAddresses,
  fail,
  parseArgs,
  parseIndex,
  printJson,
  readEnvMap,
  readSelection
} = require('./wallet-common.js')

;(async () => {
  try {
    const args = parseArgs(process.argv.slice(2))
    const env = await readEnvMap()
    const selection = await readSelection()
    const index = parseIndex(args.index, selection.index)

    if (!env.WDK_SEED) {
      printJson({
        ok: true,
        action: 'wallet_discover',
        configured: false,
        selection: {
          chain: args.chain || selection.chain,
          index
        },
        addresses: {}
      })
      return
    }

    const nextSelection = {
      chain: args.chain || selection.chain,
      index
    }

    const addresses = await deriveAddresses(env.WDK_SEED, nextSelection.index)

    printJson({
      ok: true,
      action: 'wallet_discover',
      configured: true,
      selection: nextSelection,
      addresses
    })
  } catch (error) {
    fail(error.message, { action: 'wallet_discover' })
  }
})()
