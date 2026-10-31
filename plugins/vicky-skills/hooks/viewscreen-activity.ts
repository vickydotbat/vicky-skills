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
import { clip, oneLine } from './viewscreen-text'

const MAX_DETAIL_CHARS = 60

/**
 * Says in a few words what a tool call is doing, for What's Agent Doing.
 *
 * @param tool the tool's name; a string, as the declared names are only the
 *   tools of the build that wrote the types (Grep and Glob are on some only)
 * @param args the call's arguments, whole or as far as they have streamed
 * @returns a short label such as `Reading register.tsx`
 */
export function activityOf(tool: string, args: Record<string, unknown>): string {
  const arg = (key: string): string => {
    const value = args[key]

    return typeof value === 'string' ? clip(oneLine(value), MAX_DETAIL_CHARS) : ''
  }

  const file = (key: string): string => baseName(arg(key))

  switch (tool) {
    case 'Bash':
    case 'PowerShell':
      return arg('description') || `Running ${arg('command')}`
    case 'Read':
      return `Reading ${file('file_path')}`
    case 'Edit':
      return `Editing ${file('file_path')}`
    case 'Write':
      return `Writing ${file('file_path')}`
    case 'NotebookEdit':
      return `Editing ${file('notebook_path')}`
    case 'Grep':
      return `Searching for "${arg('pattern')}"`
    case 'Glob':
      return `Finding files ${arg('pattern')}`
    case 'WebFetch':
      return `Fetching ${hostOf(arg('url'))}`
    case 'WebSearch':
      return `Searching the web for "${arg('query')}"`
    case 'Agent':
    case 'Task':
      return `Running an agent: ${arg('description')}`
    case 'TodoWrite':
      return 'Updating the todo list'
    case 'AskUserQuestion':
      return 'Waiting for your answer'
    case 'Skill':
      return `Using the ${arg('skill')} skill`
  }

  if (tool.startsWith('mcp__')) {
    const [, server = '', name = ''] = tool.split('__')

    return `Using ${server}: ${name}`
  }

  return `Using ${tool}`
}

/**
 * The string arguments a tool call's input has streamed so far, read from
 * its partial JSON: enough to name the file or command before it is whole.
 */
export function partialArgsOf(json: string): Record<string, unknown> {
  const args: Record<string, unknown> = {}

  for (const match of json.matchAll(/"([a-z_]+)"\s*:\s*"((?:[^"\\]|\\.)*)/g)) {
    const [, key = '', raw = ''] = match

    args[key] ??= unescaped(raw)
  }

  return args
}

function unescaped(raw: string): string {
  try {
    return JSON.parse(`"${raw}"`) as string
  } catch {
    return raw
  }
}

function baseName(path: string): string {
  return path.split(/[\\/]/).pop() || path
}

function hostOf(url: string): string {
  try {
    return new URL(url).host
  } catch {
    return url
  }
}
