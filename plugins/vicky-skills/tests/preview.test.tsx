// The preview pane past its approved examples: a PNG is drawn as it is, with
// no ffmpeg run, and Open tries the macOS opener only when xdg-open fails.
import { describe, expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'vicky-skills',
  component: 'Pane',
  requestId: 'preview',
  surface: 'terminal',
  props: { title: 'Preview', isFocused: true, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const
const PIXEL = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

function engine(on: any, ran: string[][], xdgExit: number) {
  mock.clock(on)
  on('command.register', () => ({ value: { command: 'preview' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  on('fs.exists', () => ({ value: true }))
  on('fs.read', () => ({ value: { bytes: Uint8Array.fromBase64(PIXEL) } }))
  on('process.run', (_: any, e: any) => {
    ran.push([...e.argv])
    return { value: { exitCode: e.argv[0] === 'xdg-open' ? xdgExit : 0, stdout: '/work/x.frame.png\n', stderr: '' } }
  })
}

describe('preview pane', () => {
  test('a PNG is drawn as it is, with no ffmpeg run', async ($, on) => {
    const ran: string[][] = []
    engine(on, ran, 0)
    await $.session.start({ cwd: '/work', surface: 'terminal', isInteractive: true })
    await $.command.run({ command: 'preview', args: 'shot.png' })
    expect(ran.some(argv => argv[0] === 'ffmpeg')).toBe(false)
  })

  for (const [xdgExit, opensMac] of [[0, false], [1, true]] as const) {
    test(`Open tries the macOS opener only when xdg-open fails (xdg-open exit ${xdgExit})`, async ($, on) => {
      const ran: string[][] = []
      engine(on, ran, xdgExit)
      await $.session.start({ cwd: '/work', surface: 'terminal', isInteractive: true })
      await $.command.run({ command: 'preview', args: 'shot.png' })
      const ui = await $.ui.mount(PANE)
      await ui.press({ key: 'open' })
      expect(ran.some(argv => argv[0] === 'open')).toBe(opensMac)
      await ui.unmount()
    })
  }
})
