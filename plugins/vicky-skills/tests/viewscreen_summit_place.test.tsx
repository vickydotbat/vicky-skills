// The band's place and summit lines: where they sit, and which output sets the summit.
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

const LINE = 'Since Sat: 4 opened, 9 closed · 30 days: +611 / −451, C'
type Call = Parameters<Engine['tool']['call']>[0]

describe('summit and place lines', () => {
  test('a search that quotes summit mid-line sets no summit', async ($, on) => {
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    on('tool.call', async () => ({ result: { stdout: 'hooks/viewscreen.tsx:620:  matchAll(/summit: ((?:x)*)/g)\nscripts/summit.sh:49:  echo "summit: $out"\n', stderr: '' } }) as never)
    const ui = await $.ui.mount(BAND)

    await $.tool.call({ tool: 'Bash', command: 'grep -n summit hooks scripts' } as Call)

    expect(await ui.find({ key: 'summit' })).toBeUndefined()
  })

  test('a summit line that opens the output still counts', async ($, on) => {
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    on('tool.call', async () => ({ result: { stdout: `summit: ${LINE}\n`, stderr: '' } }) as never)
    const ui = await $.ui.mount(BAND)

    await $.tool.call({ tool: 'Bash', command: 'bash scripts/summit.sh show' } as Call)

    expect((await ui.find({ key: 'summit' }))?.text ?? '').toContain(`⛰ ${LINE}`)
  })

  test('the summit, then the checkout marked ⎇, sit above the Claude line', async ($, on) => {
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('process.run', () => ({ value: { exitCode: 0, stdout: '/r/.git\n/r/.git\n', stderr: '' } }))
    on('tool.call', async () => ({ result: { stdout: `recorded\nsummit: ${LINE}\n`, stderr: '' } }) as never)
    await $.session.start({ cwd: '/r' } as never)
    const ui = await $.ui.mount(BAND)

    await $.tool.call({ tool: 'Bash', command: 'bash scripts/summit.sh show' } as Call)

    const text = (await ui.find({ key: 'frame' }))?.text ?? ''
    expect(text).toContain('⎇ ')
    expect(text).toContain('· main checkout')
    expect(text.indexOf(LINE)).toBeGreaterThanOrEqual(0)
    expect(text.indexOf(LINE)).toBeLessThan(text.indexOf('main checkout'))
    expect(text.indexOf('main checkout')).toBeLessThan(text.indexOf('Claude:'))
  })

  test('the main checkout names its branch, and a command that switches it updates the line', async ($, on) => {
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    let branch = 'main'
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('process.run', (_$: unknown, e: { argv: string[] }) => ({
      value: { exitCode: 0, stderr: '', stdout: e.argv.includes('rev-parse') ? '/r/.git\n/r/.git\n' : `${branch}\n` },
    }))
    on('tool.call', async () => ({ result: { stdout: '', stderr: '' } }) as never)
    await $.session.start({ cwd: '/r' } as never)
    const ui = await $.ui.mount(BAND)

    expect((await ui.find({ key: 'place' }))?.text ?? '').toContain('⎇ main · main checkout')

    branch = 'fix-band'
    await $.tool.call({ tool: 'Bash', command: 'git switch -c fix-band' } as Call)

    expect((await ui.find({ key: 'place' }))?.text ?? '').toContain('⎇ fix-band · main checkout')
  })

  test('a move into a worktree changes the line to that worktree', async ($, on) => {
    mock.clock(on, { now: 1_000_000 })
    on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
      const { Box } = $.ui.resolve(e)
      return <Box key="engine" />
    })
    let folder = '/r'
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('session.cwd', () => ({ value: folder }))
    on('process.run', (_$: unknown, e: { argv: string[] }) => {
      const inWorktree = e.argv.includes('/r/.claude/worktrees/w')
      const stdout = e.argv.includes('rev-parse')
        ? (inWorktree ? '/r/.git/worktrees/w\n/r/.git\n' : '/r/.git\n/r/.git\n')
        : (inWorktree ? 'w-branch\n' : 'main\n')
      return { value: { exitCode: 0, stderr: '', stdout } }
    })
    on('tool.call', async () => ({ result: { stdout: '', stderr: '' } }) as never)
    await $.session.start({ cwd: '/r' } as never)
    const ui = await $.ui.mount(BAND)

    folder = '/r/.claude/worktrees/w'
    await $.tool.call({ tool: 'EnterWorktree', name: 'w' } as unknown as Call)

    expect((await ui.find({ key: 'place' }))?.text ?? '').toContain('⎇ worktree: w-branch')
  })
})
