// approved-spec: the examples approved on the star "Bring whats-agent-doing
// into the plugin". Each test is named after its example and drives the
// viewscreen band through Claude Code's mod test kit.
import type { On, TurnStepChunk } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const BAND = {
  plugin: 'vicky-skills',
  surface: 'terminal',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 100,
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

const DONE = {
  answer: 'All fixed.',
  durationMs: 1000,
  isAborted: false,
  reason: 'answer',
  category: null,
  explanation: null,
} as const

const SPAWN = {
  prompt: 'Do the work.',
  subagentType: 'general-purpose',
  provider: { plugin: 'engine', tier: 'core' },
  parentModel: 'claude-opus-5-5',
  background: true,
  fork: false,
} as const

// The engine beneath the band: a clock, turns, a model with no steps, and
// tools that answer `toolAnswer`. `seen` keeps what the band said during
// each tool call.
function seat(on: On) {
  const box = {
    read: async () => '',
    seen: [] as string[],
    toolAnswer: { deny: 'stubbed in the test' } as unknown,
    onTool: async () => {},
  }
  const clock = mock.clock(on, { now: 1_000_000 })

  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Box } = $.ui.resolve(e)
    return <Box key="engine" />
  })
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('classic.PermissionRequest', () => ({}))
  on('turn.step', async function* ($, e) {
    for (const chunk of [] as TurnStepChunk[]) yield chunk
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null } as const
  })
  on('tool.call', async () => {
    await box.onTool()
    box.seen.push(await box.read())
    return box.toolAnswer as never
  })

  return { box, clock }
}

async function mount($: Engine, box: { read: () => Promise<string> }) {
  const ui = await $.ui.mount(BAND)
  box.read = async () => (await ui.find({ key: 'activity' }))?.text ?? ''
  return ui
}

describe('viewscreen', () => {
  test('a session partway through a step shows a band above the prompt naming the step and how long it has been on it', async ($, on) => {
    const { box, clock } = seat(on)
    await mount($, box)
    await $.turn.start({ text: 'fix the config', turnId: 't1' })

    box.onTool = async () => { await clock.advance(12_000) }
    await $.tool.call({ tool: 'Read', file_path: 'src/app.ts' })

    expect(box.seen[0]).toContain('Reading app.ts')
    expect(box.seen[0]).toContain('12s')
  })

  test('opening the band shows every step taken this session, each marked done, failed, denied or interrupted', async ($, on) => {
    const { box } = seat(on)
    on('agent.spawn', ($, e) => ({ model: 'claude-opus-5-5', agentId: e.tool_use_id === 'tu1' ? 'a1' : 'a2' }))
    const ui = await mount($, box)

    await $.turn.start({ text: 'fix the config', turnId: 't1' })
    await $.tool.call({ tool: 'Read', file_path: 'src/app.ts' })
    await $.agent.spawn({ ...SPAWN, tool_use_id: 'tu1', description: 'Draft the plan' })
    await $.agent.spawn({ ...SPAWN, tool_use_id: 'tu2', description: 'Storyboard the video' })
    await $.turn.complete({ ...DONE, turnId: 't1' })
    await $.turn.complete({ ...DONE, turnId: 't2', agentId: 'a2' })
    await $.turn.complete({ ...DONE, turnId: 't3', agentId: 'a1', reason: 'error' })
    await $.turn.start({ text: 'try again', turnId: 't4' })
    await $.turn.complete({ ...DONE, turnId: 't4', isAborted: true, reason: 'aborted' })

    expect(await ui.find({ key: 'history' })).toBeUndefined()
    await ui.press({ key: 'toggle' })
    const history = (await ui.find({ key: 'history' }))?.text ?? ''

    expect(history).toContain('fix the config')
    expect(history).toContain('try again')
    expect(history).toContain('✓ Agent: Storyboard the video')
    expect(history).toContain('✗ Agent: Draft the plan')
    expect(history).toContain('⊘ Reading app.ts')
    expect(history).toContain('■')
  })

  test('two background agents running each get their own row with what they are doing', async ($, on) => {
    const { box, clock } = seat(on)
    on('agent.spawn', ($, e) => ({ model: 'claude-opus-5-5', agentId: e.tool_use_id === 'tu1' ? 'a1' : 'a2' }))
    const ui = await mount($, box)

    const { turnId } = await $.turn.start({ text: 'launch the panel', turnId: 't1' })
    await $.agent.spawn({ ...SPAWN, tool_use_id: 'tu1', description: 'Draft the plan' })
    await $.agent.spawn({ ...SPAWN, tool_use_id: 'tu2', description: 'Storyboard the video' })
    await $.turn.complete({ ...DONE, turnId })
    await $.tool.call({ tool: 'Read', file_path: 'README.md', agentId: 'a1' } as Parameters<Engine['tool']['call']>[0])
    await clock.advance(300)

    const team = (await ui.find({ key: 'agents' }))?.text ?? ''
    expect(await box.read()).toContain('2 agents working')
    expect(team).toContain('Draft the plan › Reading README.md')
    expect(team).toContain('Storyboard the video › Getting started')
  })
})
