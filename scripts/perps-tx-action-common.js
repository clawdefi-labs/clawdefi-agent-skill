'use strict'

const {
  loadAdapter,
  parseArgs,
  parseTxArgs,
  printFailure,
  printSuccess,
  stringifyBigInts,
  withWalletContext
} = require('./perps-common.js')

async function runPerpsTxAction ({ moduleName, executionIntent }) {
  const args = parseArgs(process.argv.slice(2))
  const { adapter } = loadAdapter(args.adapter)

  const txRequest = parseTxArgs(args, { requireTx: true })
  const params = {
    adapter,
    chain: args.chain || null,
    index: args.index || null,
    market: args.market || null,
    side: args.side || null,
    positionId: args['position-id'] || null,
    txRequest: stringifyBigInts(txRequest)
  }

  try {
    const data = await withWalletContext(args, executionIntent, async ({ account, address, selection }) => {
      if (executionIntent === 'simulate') {
        const quote = await account.quoteSendTransaction(txRequest)
        return {
          mode: 'simulate',
          address,
          selection,
          txRequest: stringifyBigInts(txRequest),
          simulation: stringifyBigInts(quote)
        }
      }

      const sent = await account.sendTransaction(txRequest)
      return {
        mode: 'execute',
        address,
        selection,
        txRequest: stringifyBigInts(txRequest),
        transaction: stringifyBigInts(sent)
      }
    })

    printSuccess({
      module: moduleName,
      adapter,
      params,
      data,
      warnings: []
    })
  } catch (error) {
    printFailure(moduleName, adapter, params, error)
  }
}

module.exports = {
  runPerpsTxAction
}
