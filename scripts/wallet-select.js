'use strict'

const {
  fail,
  normalizeChain,
  parseArgs,
  parseIndex,
  printJson,
  readSelection,
  writeSelection
} = require('./wallet-common.js')

;(async () => {
  try {
    const args = parseArgs(process.argv.slice(2))
    const current = await readSelection()
    const selection = await writeSelection({
      chain: normalizeChain(args.chain || current.chain),
      index: parseIndex(args.index, current.index)
    })

    printJson({
      ok: true,
      action: 'wallet_select',
      selection
    })
  } catch (error) {
    fail(error.message, { action: 'wallet_select' })
  }
})()
