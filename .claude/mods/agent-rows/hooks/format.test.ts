import type { AgentInfo } from 'claude-code'
import { expect, test } from 'claude-code/testing'

import { duration, formatRow, shortModel } from './format'

const plain = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '')

const NOW = 1_000_000_000

const agent = (over: Partial<AgentInfo> = {}): AgentInfo => ({
  id: 'a1',
  description: 'Find callers',
  type: 'Explore',
  status: 'running',
  kind: 'local_agent',
  taskStatus: 'running',
  label: 'Find callers',
  startTime: NOW - 192_000,
  cwd: '/tmp',
  model: 'claude-sonnet-5-5',
  contextWindowSize: 200_000,
  tokenCount: 46_000,
  tokenSamples: [46_000],
  hasRow: true,
  ...over,
})

test('model names drop the claude- prefix and the version', () => {
  expect(shortModel('claude-opus-5-5')).toBe('opus')
  expect(shortModel('claude-haiku-5-5-20261001')).toBe('haiku')
})

test('a running agent shows model, effort, context and elapsed time', () => {
  const row = plain(formatRow(agent({ effort: 'high', cost: { usd: 0.42 } }), NOW, false))
  expect(row).toBe('Explore (sonnet high, 23% ctx) 3m12s  Find callers')
})

test('cost shows only where tokens are billed', () => {
  const row = plain(formatRow(agent({ cost: { usd: 0.4234 } }), NOW, true))
  expect(row).toBe('Explore (sonnet, 23% ctx) $0.42 3m12s  Find callers')
})

test('the progress summary replaces the description, first line only', () => {
  const row = plain(formatRow(agent({ name: 'scout', label: 'Reading auth\nmore' }), NOW, false))
  expect(row).toBe('scout (sonnet, 23% ctx) 3m12s  Reading auth')
})

test('a finished agent counts down its prompt cache instead of elapsed time', () => {
  const lastRequest = { at: NOW - 120_000, model: 'claude-opus-5-5', cacheTtl: '5m' as const }
  const row = plain(formatRow(agent({ status: 'completed', lastRequest }), NOW, false))
  expect(row).toBe('Explore (opus, 23% ctx) cache 3m00s left  Find callers')
})

test('an expired cache says so', () => {
  const lastRequest = { at: NOW - 400_000, model: 'claude-opus-5-5', cacheTtl: '5m' as const }
  expect(plain(formatRow(agent({ status: 'idle', lastRequest }), NOW, false))).toContain('cache cold')
})

test('durations roll over to minutes and hours', () => {
  expect(duration(59_000)).toBe('59s')
  expect(duration(3_725_000)).toBe('1h02m')
})
