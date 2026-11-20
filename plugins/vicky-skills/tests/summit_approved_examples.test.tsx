// approved-spec: the band examples ticked on the drafts page for
// summit-automatic, 2026-11-20, and those approved on the star "Summit: an
// opened-versus-closed record", 2026-11-01. Each test drives the viewscreen
// band through Claude Code's mod test kit: the band reads the kept summit line
// itself, from the repo's common git folder, and also learns it from a `summit:` line in a
// tool's output.
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

const LINE = 'Since Fri: 0 opened, 3 closed · 30 days: +322 / −30, C'

function engine(on: Parameters<Parameters<typeof test>[1]>[1]): void {
  mock.clock(on, { now: 1_000_000 })
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Box } = $.ui.resolve(e)
    return <Box key="engine" />
  })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
}

describe('summit', () => {
  // Given a repo whose tracker doc has a Summit count line, and your last session started on Friday
  // When a session starts
  // Then the band shows Since Fri: 0 opened, 3 closed · 30 days: +322 / −30, C
  // And the agent is told nothing about tracker counts or the summit
  test('the band shows the summit with no agent work', async ($, on) => {
    engine(on)
    on('process.run', () => ({ value: { exitCode: 0, stderr: '', stdout: '/r/.git\n/r/.git\n' } }))
    on('fs.read', (_$: unknown, e: { path: string }) => {
      if (e.path === '/r/.git/summit-line') return { value: `${LINE}\n` }
      throw new Error('no such file')
    })
    await $.session.start({ cwd: '/r' } as never)
    const ui = await $.ui.mount(BAND)

    expect((await ui.find({ key: 'summit' }))?.text ?? '').toContain(LINE)
  })

  // Given a repo whose tracker doc has no Summit count line
  // When a session starts
  // Then the band shows no summit line, and the agent is told nothing about it
  test('no Summit count line, no summit', async ($, on) => {
    engine(on)
    on('process.run', () => ({ value: { exitCode: 0, stderr: '', stdout: '/r/.git\n/r/.git\n' } }))
    on('fs.read', () => { throw new Error('no such file') })
    await $.session.start({ cwd: '/r' } as never)
    const ui = await $.ui.mount(BAND)

    expect(await ui.find({ key: 'activity' })).toBeDefined()
    expect(await ui.find({ key: 'summit' })).toBeUndefined()
  })

  // Given four tickets opened and nine closed since your last session, which started on Saturday 31 October, and 611 opened and 451 closed in the last 30 days
  // When the viewscreen band shows
  // Then the band reads Since Sat: 4 opened, 9 closed · 30 days: +611 / −451, C
  test('the summit in the viewscreen band', async ($, on) => {
    const told = 'Since Sat: 4 opened, 9 closed · 30 days: +611 / −451, C'
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    on('tool.call', async () => ({ result: { stdout: `summit: ${told}\n`, stderr: '' } }) as never)
    const ui = await $.ui.mount(BAND)

    await $.tool.call({ tool: 'Bash', command: 'bash scripts/summit.sh show' } as Parameters<Engine['tool']['call']>[0])

    expect((await ui.find({ key: 'summit' }))?.text ?? '').toContain(told)
  })
})
