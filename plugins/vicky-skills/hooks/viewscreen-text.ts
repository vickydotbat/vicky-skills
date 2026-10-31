/**
 * Ported from whats-agent-doing by Tzafrir Rehan, version 0.4.3, under the
 * MIT License, as the viewscreen band of vicky-skills.
 *
 * MIT License
 *
 * Copyright (c) 2026 Tzafrir Rehan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/** Collapses runs of whitespace, newlines included, to single spaces. */
export function oneLine(text: string): string {
  return text.replace(/\s+/g, ' ').trim()
}

/** Cuts `text` to `max` characters, marking the cut with an ellipsis. */
export function clip(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text
}

/**
 * The sentence Claude is thinking right now: the tail of the thought so far,
 * with the sentence before it when the current one has barely started.
 *
 * @param thought the thinking block's text so far
 * @param max the longest snippet, cut from the front
 */
export function thoughtOf(thought: string, max: number): string {
  const flat = oneLine(thought.replace(/[*_`#>]/g, ''))

  if (flat === '') {
    return ''
  }

  const sentences = flat.split(/(?<=[.!?:])\s+/)
  const last = sentences.at(-1) ?? ''
  const before = sentences.at(-2)
  const tail = last.length < 25 && before !== undefined ? `${before} ${last}` : last

  return tail.length > max ? `…${tail.slice(-(max - 1))}` : tail
}

export function wordsIn(text: string): number {
  return text.split(/\s+/).filter(Boolean).length
}

export function plural(count: number, word: string): string {
  return `${count} ${word}${count === 1 ? '' : 's'}`
}

/** `840 B`, `2.3 KB`, `1.1 MB`. */
export function sizeOf(chars: number): string {
  if (chars < 1024) {
    return `${chars} B`
  }

  if (chars < 1024 * 1024) {
    return `${(chars / 1024).toFixed(1)} KB`
  }

  return `${(chars / 1024 / 1024).toFixed(1)} MB`
}

/** `0.4s` under ten seconds, `12s` under a minute, `3m 05s` after. */
export function durationOf(ms: number): string {
  const seconds = Math.max(0, ms) / 1000

  if (seconds < 10) {
    return `${seconds.toFixed(1)}s`
  }

  if (seconds < 60) {
    return `${Math.floor(seconds)}s`
  }

  const minutes = Math.floor(seconds / 60)
  const rest = Math.floor(seconds % 60)

  return `${minutes}m ${String(rest).padStart(2, '0')}s`
}

/**
 * A label safe to draw: control, format and line-separator characters out
 * (the engine refuses a drawing holding one), whitespace collapsed, and cut
 * to `max`. Labels carry paths, commands and thoughts the model wrote.
 */
export function printable(text: string, max: number): string {
  const spaced = text.replace(/[\p{Cc}\p{Zl}\p{Zp}]/gu, ' ').replace(/\p{Cf}/gu, '')

  return clip(oneLine(spaced), max)
}

/**
 * Counts the words a streamed chunk adds, carrying whether the text so far
 * ends inside a word, so a reply is never counted again from its start.
 *
 * @param chunk the newly streamed text
 * @param isInWord whether the text before it ended inside a word
 */
export function wordsAdded(chunk: string, isInWord: boolean): { added: number; isInWord: boolean } {
  const words = chunk.match(/\S+/g)?.length ?? 0
  const continues = isInWord && /^\S/.test(chunk)

  return {
    added: continues ? words - 1 : words,
    isInWord: chunk === '' ? isInWord : /\S$/.test(chunk),
  }
}
