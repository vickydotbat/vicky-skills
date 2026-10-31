// approved-spec: the examples the user set for the viewscreen band's layout:
// full terminal width, one border colour, never blank. Each test is named
// after its example and drives the band through Claude Code's mod test kit.
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

function band(bodyColumns: number, hasSurvey = false) {
  return {
    plugin: 'vicky-skills',
    surface: 'terminal',
    component: 'AbovePrompt',
    props: { hasSurvey, isWorking: false, maxRows: 20, bodyColumns, scroll: { offset: 0, bodyRows: 20 }, view: {} },
  } as const
}

async function frame($: Engine, columns: number, hasSurvey = false) {
  const ui = await $.ui.mount(band(columns, hasSurvey))
  return { ui, box: await ui.find({ key: 'frame' }), text: (await ui.find({ key: 'activity' }))?.text ?? '' }
}

describe('viewscreen layout', () => {
  test('the band is as wide as the terminal, idle or working, with short or long text, and changes only with the terminal', async ($, on) => {
    mock.clock(on)
    on('turn.start', ($, e) => ({ turnId: e.turnId }))
    on('tool.call', () => ({ deny: 'stubbed' }))

    expect((await frame($, 100)).box?.props.width).toBe(100)
    await $.turn.start({ text: 'x'.repeat(300), turnId: 't1' })
    expect((await frame($, 100)).box?.props.width).toBe(100)
    await $.tool.call({ tool: 'Read', file_path: 'src/a.ts' })
    expect((await frame($, 100)).box?.props.width).toBe(100)
    expect((await frame($, 80)).box?.props.width).toBe(80)
  })

  test('every wall of the border is one colour, the same in every phase', async ($, on) => {
    mock.clock(on)
    on('turn.start', ($, e) => ({ turnId: e.turnId }))

    const idle = (await frame($, 100)).box?.props
    await $.turn.start({ text: 'fix it', turnId: 't1' })
    const working = (await frame($, 100)).box?.props

    for (const props of [idle, working]) {
      expect(props?.borderColor).toBeDefined()
      for (const side of ['borderTopColor', 'borderBottomColor', 'borderLeftColor', 'borderRightColor']) {
        expect(props?.[side]).toBeUndefined()
      }
    }
    expect(working?.borderColor).toBe(idle?.borderColor)
  })

  test('the band always shows text, never blank, a survey showing included', async ($, on) => {
    mock.clock(on)
    on('turn.start', ($, e) => ({ turnId: e.turnId }))

    expect((await frame($, 100)).text.trim()).not.toBe('')
    expect((await frame($, 100, true)).text.trim()).not.toBe('')
    await $.turn.start({ text: '', turnId: 't1' })
    expect((await frame($, 100)).text.trim()).not.toBe('')
  })
})
