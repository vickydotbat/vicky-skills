// approved-spec: the "Preview media from the chat" examples, approved
// 2026-11-02. The engine beneath the mod is played by the test's hooks: the
// files that exist, what ffmpeg writes, and the opener the Open button runs.
import { describe, expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'vicky-skills',
  component: 'Pane',
  requestId: 'preview',
  props: { title: 'Preview', isFocused: true, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const
// A whole PNG, one pixel, base64.
const PIXEL = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

// The engine stand-in: `files` exist, ffmpeg writes a PNG, and every command is recorded.
function engine(on: any, files: string[], ran: string[][], opened: string[] = []) {
  on('command.register', () => ({ value: { command: 'preview' } }))
  on('ui.open', (_: any, e: any) => { opened.push(e.id); return { value: { isPlaced: true } } })
  mock.clock(on)
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  on('fs.exists', (_: any, e: any) => ({ value: files.includes(e.path) || e.path.endsWith('.frame.png') }))
  on('fs.read', () => ({ value: { bytes: Uint8Array.fromBase64(PIXEL) } }))
  on('process.run', (_: any, e: any) => {
    ran.push([...e.argv])
    return { value: { exitCode: 0, stdout: '/tmp/x.frame.png\n', stderr: '' } }
  })
}

describe('preview', () => { for (const surface of ['terminal', 'desktop'] as const) {
  // Given a terminal that draws images (kitty, Ghostty or iTerm2) and a PNG or JPEG path named in the chat
  // When you type /preview with that path
  // Then a pane beside the chat shows the picture
  test(`an image shows beside the chat (${surface})`, async ($, on) => {
    const ran: string[][] = []
    engine(on, ['/work/shot.png'], ran)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.command.run({ command: 'preview', args: '/work/shot.png' })
    const ui = await $.ui.mount({ ...PANE, surface })
    if (surface === 'terminal') expect((await ui.find({ type: 'Image' }))?.props?.source?.png).toBe(PIXEL)
    expect((await ui.find({ type: 'Text', text: /shot\.png/ }))?.text).toContain('shot.png')
    await ui.unmount()
  })

  // Given a terminal that can't draw images
  // When you type /preview with an image path
  // Then the pane shows the file's name and an Open button, and Open shows it in your default app
  test(`any terminal can open it (${surface})`, async ($, on) => {
    const ran: string[][] = []
    engine(on, ['/work/shot.jpg'], ran)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.command.run({ command: 'preview', args: 'shot.jpg' })
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /shot\.jpg/ }))?.text).toContain('shot.jpg')
    await ui.press({ key: 'open' })
    expect(ran.some(argv => argv.at(-1) === '/work/shot.jpg' && /open$/.test(argv[0]))).toBe(true)
    await ui.unmount()
  })

  // Given a video path named in the chat
  // When you type /preview with that path
  // Then the pane shows one still frame from it, and Open plays it in your default app
  test(`a video shows one frame (${surface})`, async ($, on) => {
    const ran: string[][] = []
    engine(on, ['/work/run.mp4'], ran)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.command.run({ command: 'preview', args: '/work/run.mp4' })
    expect(ran.some(argv => argv[0] === 'ffmpeg' && argv.includes('/work/run.mp4') && argv[argv.indexOf('-ss') + 1] === '1')).toBe(true)
    const ui = await $.ui.mount({ ...PANE, surface })
    if (surface === 'terminal') expect((await ui.find({ type: 'Image' }))?.props?.source?.png).toBe(PIXEL)
    await ui.press({ key: 'open' })
    expect(ran.some(argv => argv.at(-1) === '/work/run.mp4' && /open$/.test(argv[0]))).toBe(true)
    await ui.unmount()
  })

  // Given the chat has named an image or video path
  // When you look at the status line
  // Then it shows the newest one as a link, and clicking it opens the file in your default app
  test(`the newest media is one click away (${surface})`, async ($, on) => {
    const ran: string[][] = []
    const lines: (string | undefined)[] = []
    engine(on, ['/work/old.png', '/work/new.mp4'], ran)
    on('ui.status', (_: any, e: any) => { lines.push(e.text); return { value: undefined } })
    on('turn.complete', (_: any, e: any) => e)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.turn.complete({ text: 'Saved /work/old.png, then rendered /work/new.mp4.' } as any)
    expect(lines.at(-1)).toContain('file:///work/new.mp4')
  })

  // Given a path that doesn't exist
  // When you type /preview with it
  // Then the pane says the file isn't there, and nothing opens
  test(`a missing file says so (${surface})`, async ($, on) => {
    const ran: string[][] = []
    engine(on, [], ran)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.command.run({ command: 'preview', args: '/work/gone.png' })
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /isn't there/ }))?.text).toContain('gone.png')
    expect(await ui.find({ type: 'Button' })).toBeUndefined()
    expect(ran.some(argv => /open$/.test(argv[0]) || argv[0] === 'ffmpeg')).toBe(false)
    await ui.unmount()
  })

  // Given Claude's reply names an image or video path that exists
  // When the reply ends
  // Then the pane opens and shows it, with no /preview typed
  test(`a reply's media opens the pane by itself (${surface})`, async ($, on) => {
    const ran: string[][] = []
    const opened: string[] = []
    engine(on, ['/work/chart.png'], ran, opened)
    on('turn.complete', (_: any, e: any) => e)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.turn.complete({ text: 'The chart is at /work/chart.png.' } as any)
    expect(opened).toContain('preview')
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /chart\.png/ }))?.text).toContain('chart.png')
    await ui.unmount()
  })

  // Given Claude's reply names a path that doesn't exist
  // When the reply ends
  // Then the pane stays as it was
  test(`a reply naming a missing file leaves the pane alone (${surface})`, async ($, on) => {
    const ran: string[][] = []
    const opened: string[] = []
    engine(on, ['/work/a.png'], ran, opened)
    on('turn.complete', (_: any, e: any) => e)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.command.run({ command: 'preview', args: '/work/a.png' })
    const before = opened.length
    await $.turn.complete({ text: 'It would be at /work/nothing.png.' } as any)
    expect(opened.length).toBe(before)
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /a\.png/ }))?.text).toContain('a.png')
    await ui.unmount()
  })

  // Given you paste an image into your message, or name an image or video path in it
  // When you send it
  // Then the pane opens and shows it
  test(`your message's media opens the pane (${surface})`, async ($, on) => {
    const ran: string[][] = []
    const opened: string[] = []
    engine(on, ['/work/clip.mp4'], ran, opened)
    on('prompt.submit', (_: any, e: any) => e)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.prompt.submit({ text: 'look at clip.mp4 please' } as any)
    expect(opened).toContain('preview')
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /clip\.mp4/ }))?.text).toContain('clip.mp4')
    await ui.unmount()
  })

  // Given one message names two images
  // When it is sent or the reply ends
  // Then the pane shows the last one named, and /preview still shows any other
  test(`the last one named wins (${surface})`, async ($, on) => {
    const ran: string[][] = []
    engine(on, ['/work/one.png', '/work/two.png'], ran)
    on('turn.complete', (_: any, e: any) => e)
    await $.session.start({ cwd: '/work', surface, isInteractive: true })
    await $.turn.complete({ text: 'See /work/one.png and /work/two.png.' } as any)
    let ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /\.png/ }))?.text).toContain('two.png')
    await ui.unmount()
    await $.command.run({ command: 'preview', args: '/work/one.png' })
    ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /\.png/ }))?.text).toContain('one.png')
    await ui.unmount()
  })
} })
