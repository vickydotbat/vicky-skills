// approved-spec: the band examples approved on the star "Summit: an
// opened-versus-closed record", 2026-11-01. Each test is named after its
// example and drives the viewscreen band through Claude Code's mod test kit:
// the band learns the summit from the `summit:` line that summit.sh prints.
import { describe, expect, test } from 'claude-code/testing'
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

const LINE = 'Since Sat: 4 opened, 9 closed · 30 days: +611 / −451, C'

describe('summit', () => {
  // Given four tickets opened and nine closed since your last session, which started on Saturday 31 October, and 611 opened and 451 closed in the last 30 days
  // When the viewscreen band shows
  // Then the band reads Since Sat: 4 opened, 9 closed · 30 days: +611 / −451, C
  test('the summit in the viewscreen band', async ($, on) => {
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    on('tool.call', async () => ({ result: { stdout: `recorded\nsummit: ${LINE}\n`, stderr: '' } }) as never)
    const ui = await $.ui.mount(BAND)

    await $.tool.call({ tool: 'Bash', command: 'bash scripts/summit.sh record 611 451 4 9' } as Parameters<Engine['tool']['call']>[0])

    expect((await ui.find({ key: 'summit' }))?.text ?? '').toContain(LINE)
  })

  // Given a session where nothing has been counted yet
  // When the viewscreen band shows
  // Then the band shows no summit line
  test('the summit before anything is counted', async ($, on) => {
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    const ui = await $.ui.mount(BAND)

    expect(await ui.find({ key: 'summit' })).toBeUndefined()
  })
})
