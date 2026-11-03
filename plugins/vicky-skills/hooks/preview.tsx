// /preview <path> opens a pane beside the chat with the picture, or a
// video's first-second frame, and an Open button for the desktop's own app.
// The status line keeps the newest media path the chat named as a link.
import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { PreviewShown } from '../types'

const PANE = 'preview'
const shown = atom({ plugin: 'vicky-skills', key: 'preview' } as const, null as PreviewShown | null, { shape: 'preview-1' })
const IMAGE = /\.(png|jpe?g|gif|webp|bmp)$/i
const VIDEO = /\.(mp4|mov|webm|mkv|avi|m4v)$/i
const MEDIA = /(?:^|[\s"'`(])((?:~|\.{0,2})?\/?[\w./~-]+\.(?:png|jpe?g|gif|webp|bmp|mp4|mov|webm|mkv|avi|m4v))(?=$|[\s"'`),.;:!?])/gim

// The engine takes one unmatched hook per event from a plugin, so
// viewscreen.tsx calls these two from its own session.start and turn.complete.
let cwd = '/'

const absolute = (path: string) => (path.startsWith('/') ? path : `${cwd.replace(/\/$/, '')}/${path.replace(/^\.\//, '')}`)

export async function previewStarted($: any, at: string | undefined) {
  cwd = at ?? cwd
  // A host that can't add the command still runs the rest of the session.
  await $.command.register({ name: 'preview', description: 'Show an image or a video frame in a pane beside the chat' }).catch(() => undefined)
}

export function previewCompleted($: any, text: string | undefined) {
  const newest = [...String(text ?? '').matchAll(MEDIA)].map(m => m[1]).at(-1)
  if (newest) $.ui.status(`▶ file://${absolute(newest)}`)
}

export const registerPreview: Register = on => {
  on('command.run', { command: 'preview' }, async ($, e) => {
    const path = absolute(String(e.args ?? '').trim())
    if (!path || path.endsWith('/')) return { text: 'Usage: /preview <path to an image or video>' }
    let next: PreviewShown
    if (!(await $.fs.exists(path))) {
      next = { path, kind: 'missing', png: null }
    } else {
      const isVideo = VIDEO.test(path)
      next = { path, kind: isVideo ? 'video' : 'image', png: await picture($, path, isVideo) }
    }
    await update($, shown, () => next)
    await $.ui.open({ id: PANE, title: 'Preview' })
    return { text: next.kind === 'missing' ? `${path} isn't there.` : `Previewing ${path}.` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Image } = $.ui.resolve(e) as any
    const now = await read($, shown)
    if (!now) return <Text dimColor>Type /preview with a path.</Text>
    const name = now.path.split('/').at(-1) ?? now.path
    if (now.kind === 'missing') return <Text>{`${now.path} isn't there.`}</Text>
    const columns = Math.max(10, Math.min(120, (e.props as { bodyColumns?: number })?.bodyColumns ?? 60))
    return (
      <Box flexDirection="column">
        <Text>{now.kind === 'video' ? `${name} (a frame from the video)` : name}</Text>
        {Image && now.png && <Image source={{ png: now.png }} columns={columns} rows={Math.max(4, Math.round(columns / 3))} alt={name} />}
        <Button key="open" onPress={() => void openIt($, now.path)}>Open</Button>
      </Box>
    )
  })
}

// A PNG the pane can draw: the file itself for a PNG, otherwise ffmpeg's
// PNG of the picture, or of the video at one second in. Null when ffmpeg fails.
async function picture($: any, path: string, isVideo: boolean): Promise<string | null> {
  let source = path
  if (isVideo || !/\.png$/i.test(path)) {
    const made = await $.process.run(['mktemp', '--suffix=.frame.png'])
    const out = made.exitCode === 0 ? made.stdout.trim() : ''
    if (!out) return null
    const seek = isVideo ? ['-ss', '1'] : []
    const ran = await $.process.run(['ffmpeg', '-y', '-loglevel', 'error', ...seek, '-i', path, '-frames:v', '1', out], { timeoutMs: 20000 })
    if (ran.exitCode !== 0) return null
    source = out
  }
  const { bytes } = await $.fs.read(source, { as: 'bytes' })
  if (typeof bytes?.toBase64 === 'function') return bytes.toBase64()
  // Bytes that crossed as plain data arrive as an array or an index-keyed object.
  const list: number[] = Array.isArray(bytes) ? bytes : Object.values(bytes ?? {})
  return list.length ? btoa(list.map(b => String.fromCharCode(b)).join('')) : null
}

// The desktop's default app: xdg-open on Linux, open on macOS.
async function openIt($: any, path: string) {
  const linux = await $.process.run(['xdg-open', path]).catch(() => ({ exitCode: 127 }))
  if (linux.exitCode !== 0) await $.process.run(['open', path]).catch(() => undefined)
}
