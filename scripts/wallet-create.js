'use strict'

const {
  deriveAddresses,
  fail,
  loadWalletModules,
  parseArgs,
  parseIndex,
  printJson,
  writeEnvValue,
  writeSelection
} = require('./wallet-common.js')

;(async () => {
  try {
    const args = parseArgs(process.argv.slice(2))
    const wordCount = Number(args['word-count'] || 12)
    if (![12, 24].includes(wordCount)) {
      throw new Error('word-count must be 12 or 24')
    }

    const index = parseIndex(args.index, 0)
    const { WalletManagerEvm } = await loadWalletModules()
    const seedPhrase = WalletManagerEvm.getRandomSeedPhrase(wordCount)

    await writeEnvValue('WDK_SEED', seedPhrase)
    const selection = await writeSelection({
      chain: args.chain || 'ethereum',
      index
    })

    const addresses = await deriveAddresses(seedPhrase, selection.index)

    printJson({
      ok: true,
      action: 'wallet_create',
      selection,
      addresses,
      seedPhrase,
      warning: 'Back up this seed phrase now. ClawDeFi will not recover it for you.'
    })
  } catch (error) {
    fail(error.message, { action: 'wallet_create' })
  }
})()
