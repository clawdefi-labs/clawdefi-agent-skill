'use strict'

const DEFAULT_API_BASE_URL = String(process.env.PENDLE_CORE_API_BASE_URL || 'https://api-v2.pendle.finance/api/core')
  .trim()
  .replace(/\/+$/, '')

const SUPPORTED_SORT_BY = new Set([
  'liquidity',
  'aggregated-apy',
  'implied-apy',
  'pendle-apy',
  'expiry',
  'name'
])

function normalizeAddressRef (value) {
  const raw = String(value || '').trim()
  if (!raw) return null
  const normalized = raw.includes('-') ? raw.split('-', 2)[1] : raw
  return normalized.toLowerCase()
}

function normalizeMarket (market, { chainId, chainSlug }) {
  const details = market && typeof market.details === 'object' && market.details
    ? market.details
    : {}

  return {
    chainId,
    chain: chainSlug,
    name: String(market.name || ''),
    marketAddress: normalizeAddressRef(market.address),
    expiry: market.expiry || null,
    isNew: Boolean(market.isNew),
    isPrime: Boolean(market.isPrime),
    categoryIds: Array.isArray(market.categoryIds) ? market.categoryIds.map((entry) => String(entry).toLowerCase()) : [],
    tokens: {
      pt: normalizeAddressRef(market.pt),
      yt: normalizeAddressRef(market.yt),
      sy: normalizeAddressRef(market.sy),
      underlyingAsset: normalizeAddressRef(market.underlyingAsset)
    },
    metrics: {
      liquidityUsd: Number(details.liquidity || 0),
      pendleApy: Number(details.pendleApy || 0),
      impliedApy: Number(details.impliedApy || 0),
      aggregatedApy: Number(details.aggregatedApy || 0),
      maxBoostedApy: Number(details.maxBoostedApy || 0),
      feeRate: Number(details.feeRate || 0),
      yieldRange: details.yieldRange || null
    }
  }
}

function matchesQuery (item, query) {
  if (!query) return true
  const q = String(query).trim().toLowerCase()
  if (!q) return true
  const haystack = [
    item.name,
    item.marketAddress,
    item.tokens.pt,
    item.tokens.yt,
    item.tokens.sy,
    item.tokens.underlyingAsset,
    ...(item.categoryIds || [])
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
  return haystack.includes(q)
}

function compareValues (a, b, { sortBy, order }) {
  const direction = order === 'asc' ? 1 : -1

  if (sortBy === 'name') {
    return direction * String(a.name || '').localeCompare(String(b.name || ''))
  }
  if (sortBy === 'expiry') {
    const left = Date.parse(a.expiry || '') || 0
    const right = Date.parse(b.expiry || '') || 0
    return direction * (left - right)
  }
  if (sortBy === 'aggregated-apy') {
    return direction * ((a.metrics.aggregatedApy || 0) - (b.metrics.aggregatedApy || 0))
  }
  if (sortBy === 'implied-apy') {
    return direction * ((a.metrics.impliedApy || 0) - (b.metrics.impliedApy || 0))
  }
  if (sortBy === 'pendle-apy') {
    return direction * ((a.metrics.pendleApy || 0) - (b.metrics.pendleApy || 0))
  }

  return direction * ((a.metrics.liquidityUsd || 0) - (b.metrics.liquidityUsd || 0))
}

function normalizeCategories (input) {
  if (!Array.isArray(input)) return []
  return input
    .map((value) => String(value || '').trim().toLowerCase())
    .filter(Boolean)
}

async function fetchActiveMarkets ({ chainId }) {
  const url = `${DEFAULT_API_BASE_URL}/v1/${chainId}/markets/active`
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Accept: 'application/json'
    }
  })

  const bodyText = await response.text()
  let body = null
  if (bodyText.trim()) {
    body = JSON.parse(bodyText)
  }

  if (!response.ok) {
    const detail = body && typeof body === 'object'
      ? (body.message || body.error || JSON.stringify(body))
      : bodyText
    throw new Error(`Pendle active markets request failed: HTTP ${response.status} ${String(detail).slice(0, 220)}`)
  }

  if (!body || !Array.isArray(body.markets)) {
    throw new Error('Unexpected Pendle active markets response shape.')
  }

  return body.markets
}

async function listOpportunities (input) {
  const warnings = []
  const categories = normalizeCategories(input.categories)
  const rawMarkets = await fetchActiveMarkets({
    chainId: input.chainId
  })

  const normalized = rawMarkets.map((entry) =>
    normalizeMarket(entry, {
      chainId: input.chainId,
      chainSlug: input.chainSlug
    })
  )

  const categoryCounter = {}
  for (const market of normalized) {
    for (const categoryId of market.categoryIds) {
      categoryCounter[categoryId] = (categoryCounter[categoryId] || 0) + 1
    }
  }

  let filtered = normalized.filter((entry) => matchesQuery(entry, input.query))

  if (categories.length) {
    filtered = filtered.filter((entry) => entry.categoryIds.some((categoryId) => categories.includes(categoryId)))
  }

  if (input.minLiquidityUsd !== null) {
    filtered = filtered.filter((entry) => entry.metrics.liquidityUsd >= input.minLiquidityUsd)
  }
  if (input.minPendleApy !== null) {
    filtered = filtered.filter((entry) => entry.metrics.pendleApy >= input.minPendleApy)
  }
  if (input.minImpliedApy !== null) {
    filtered = filtered.filter((entry) => entry.metrics.impliedApy >= input.minImpliedApy)
  }
  if (input.minAggregatedApy !== null) {
    filtered = filtered.filter((entry) => entry.metrics.aggregatedApy >= input.minAggregatedApy)
  }
  if (input.primeOnly) {
    filtered = filtered.filter((entry) => entry.isPrime)
  }
  if (input.newOnly) {
    filtered = filtered.filter((entry) => entry.isNew)
  }

  const sortBy = SUPPORTED_SORT_BY.has(input.sortBy) ? input.sortBy : 'liquidity'
  filtered.sort((left, right) => compareValues(left, right, { sortBy, order: input.sortOrder }))

  const offset = input.offset || 0
  const limit = input.limit || 20
  const sliced = filtered.slice(offset, offset + limit)

  if (!sliced.length) {
    warnings.push('no_yield_opportunities_matched_filters')
  }

  return {
    provider: 'pendle-hosted-sdk',
    chainId: input.chainId,
    chain: input.chainSlug,
    walletAddress: input.walletAddress || null,
    filter: {
      categories,
      query: input.query || null,
      minLiquidityUsd: input.minLiquidityUsd,
      minPendleApy: input.minPendleApy,
      minImpliedApy: input.minImpliedApy,
      minAggregatedApy: input.minAggregatedApy,
      primeOnly: input.primeOnly,
      newOnly: input.newOnly,
      sortBy,
      sortOrder: input.sortOrder
    },
    counts: {
      beforeFilter: normalized.length,
      afterFilter: filtered.length,
      returned: sliced.length
    },
    pagination: {
      offset,
      limit
    },
    categoriesObserved: categoryCounter,
    opportunities: sliced,
    warnings
  }
}

module.exports = {
  listOpportunities
}

