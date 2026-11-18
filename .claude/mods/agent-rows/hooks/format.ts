import type { AgentInfo } from 'claude-code'

const GREEN = '\x1b[32m'
const YELLOW = '\x1b[33m'
const RED = '\x1b[31m'
const CYAN = '\x1b[36m'
const DIM = '\x1b[2m'
const RESET = '\x1b[0m'

const paint = (color: string, text: string) => `${color}${text}${RESET}`

export const shortModel = (model: string) =>
  model.replace(/^claude-/, '').replace(/-\d.*$/, '')

// Same bands as the main statusline: large windows leave far less absolute
// headroom at the same percentage, so they turn earlier.
const contextColor = (pct: number, windowSize: number) => {
  const [low, high] = windowSize >= 500_000 ? [30, 40] : [50, 75]
  if (pct < low) return GREEN
  if (pct < high) return YELLOW
  return RED
}

export const duration = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}m`
}

const TTL_MS = { '5m': 300_000, '1h': 3_600_000 } as const

// A stopped agent is only cheap to SendMessage while its prompt cache is warm;
// once cold, its whole transcript is re-sent at the cache-write rate.
const cacheSegment = (agent: AgentInfo, now: number) => {
  const last = agent.lastRequest
  if (agent.status === 'running' || !last?.cacheTtl) return ''
  const ttl = TTL_MS[last.cacheTtl]
  const left = last.at + ttl - now
  if (left <= 0) return paint(RED, 'cache cold')
  const color = left <= ttl * 0.2 ? RED : left <= ttl * 0.5 ? YELLOW : DIM
  return paint(color, `cache ${duration(left)} left`)
}

// On a subscription the dollar figure is only an API-price estimate of what
// the plan already covers; it is real money only on a usage-based seat.
export const formatRow = (agent: AgentInfo, now: number, isBilledPerToken: boolean) => {
  const name = agent.name ?? agent.type
  const model = agent.lastRequest?.model ?? agent.model
  const effort = agent.lastRequest?.effort ?? agent.effort

  const inner = [paint(CYAN, model ? shortModel(model) : '?')]
  if (effort !== undefined) inner[0] += ` ${effort}`
  if (agent.contextWindowSize) {
    const pct = Math.floor((agent.tokenCount * 100) / agent.contextWindowSize)
    inner.push(paint(contextColor(pct, agent.contextWindowSize), `${pct}% ctx`))
  }

  const tail: string[] = []
  if (isBilledPerToken && agent.cost && agent.cost.usd >= 0.01) {
    tail.push(paint(GREEN, `$${agent.cost.usd.toFixed(2)}`))
  }
  if (agent.status === 'running') tail.push(paint(DIM, duration(now - agent.startTime)))
  if (agent.status === 'failed' || agent.status === 'killed') tail.push(paint(RED, agent.status))
  const cache = cacheSegment(agent, now)
  if (cache) tail.push(cache)

  const label = (agent.label.split('\n')[0] ?? '').trim()
  const body = label && label !== name ? `  ${label}` : ''

  return `${name} (${inner.join(', ')})${tail.length ? ' ' + tail.join(' ') : ''}${body}`
}
