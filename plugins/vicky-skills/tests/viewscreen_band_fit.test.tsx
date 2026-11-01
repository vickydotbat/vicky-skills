// The band fits the width it is given and names where the agent works.
// The mod test kit draws the tree without running layout, so the fit is
// proved on the tree: the frame gets a usable width, and the label is cut
// to the room the row leaves, so layout never has to squeeze it.
import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

function seat(on: On, git: (argv: string[]) => { exitCode: number; stdout: string } = () => ({ exitCode: 128, stdout: '' })) {
  mock.clock(on)
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Box } = $.ui.resolve(e)
    return <Box key="engine" />
  })
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('process.run', (_$: unknown, e: { argv: string[] }) => ({ value: { stderr: '', ...git(e.argv) } }))
}

async function draw($: Engine, bodyColumns: number) {
  const ui = await $.ui.mount({
    plugin: 'vicky-skills',
    surface: 'terminal',
    component: 'AbovePrompt',
    props: { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns, scroll: { offset: 0, bodyRows: 20 }, view: {} },
  } as const)
  return {
    frame: await ui.find({ key: 'frame' }),
    row: (await ui.find({ key: 'activity' }))?.text ?? '',
    place: (await ui.find({ key: 'place' }))?.text,
  }
}


describe('band fit', () => {
  test('a width of zero or less, or none, leaves the frame to size itself', async ($, on) => {
    seat(on)
    await $.turn.start({ text: 'fix it', turnId: 't1' })

    for (const columns of [0, -3, Number.NaN]) {
      expect((await draw($, columns)).frame?.props.width).toBeUndefined()
    }
  })

  test('a tiny width is raised to one the dot, name and some label fit in', async ($, on) => {
    seat(on)
    await $.turn.start({ text: 'fix it', turnId: 't1' })

    expect((await draw($, 6)).frame?.props.width).toBeGreaterThanOrEqual(30)
  })

  test('a long label is cut to the room the row leaves, with the time kept whole', async ($, on) => {
    seat(on)
    let row = ''
    let ui: Awaited<ReturnType<Engine['ui']['mount']>> | undefined
    on('turn.step', async function* ($, e) {
      yield { kind: 'thinking', index: 0, text: 'I should read the whole loader and the config before touching anything else here' }
      row = (await ui?.find({ key: 'activity' }))?.text ?? ''
      return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null } as const
    })
    on('turn.complete', ($, e) => ({ text: e.answer }))

    ui = await $.ui.mount({
      plugin: 'vicky-skills', surface: 'terminal', component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 50, scroll: { offset: 0, bodyRows: 20 }, view: {} },
    } as const)
    await $.turn.start({ text: 'fix it', turnId: 't1' })
    for await (const _ of $.turn.step({ turnId: 't1', model: 'm', messageCount: 1, index: 0 } as never)) {
      // drained
    }

    expect(row).toContain('Thinking:')
    expect(row.length).toBeLessThanOrEqual(50 - 4)
    expect(row).toMatch(/….*· \d/)
  })
})

describe('band place', () => {
  test('a linked worktree shows its branch', async ($, on) => {
    seat(on, argv => argv.includes('rev-parse')
      ? { exitCode: 0, stdout: '/r/.git/worktrees/w\n/r/.git\n' }
      : { exitCode: 0, stdout: 'viewscreen-band\n' })
    await $.session.start({ cwd: '/r/.claude/worktrees/w' } as never)

    expect((await draw($, 100)).place).toContain('viewscreen-band')
  })

  test('the main checkout says so', async ($, on) => {
    seat(on, () => ({ exitCode: 0, stdout: '/r/.git\n/r/.git\n' }))
    await $.session.start({ cwd: '/r' } as never)

    expect((await draw($, 100)).place).toContain('main checkout')
  })

  test('outside a git repo, no place line', async ($, on) => {
    seat(on)
    await $.session.start({ cwd: '/tmp' } as never)

    expect((await draw($, 100)).place).toBeUndefined()
  })
})
