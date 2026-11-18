import type { EngineInterface, Register } from 'claude-code'

import { formatRow } from './format'

// The default profile keeps its config json beside ~/.claude rather than
// inside it; a custom config dir keeps its own within.
const readSeatTier = async ($: EngineInterface) => {
  try {
    const configDir = await $.env.get('CLAUDE_CONFIG_DIR')
    const path = configDir ? `${configDir}/.claude.json` : `${await $.env.get('HOME')}/.claude.json`
    const config = JSON.parse(await $.fs.read(path)) as { oauthAccount?: { seatTier?: string } }
    return config.oauthAccount?.seatTier
  } catch {
    return undefined
  }
}

export const register: Register = on => {
  let isBilledPerToken: Promise<boolean> | undefined

  on('ui.render', { component: 'AgentRow' }, async ($, e, next) => {
    isBilledPerToken ??= readSeatTier($).then(tier => tier === 'enterprise_usage_based')
    const body = formatRow(e.props, await $.clock.now(), await isBilledPerToken)

    return next({ ...e, props: { ...e.props, body } })
  })
}
