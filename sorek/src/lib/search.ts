import type { OcrWord } from './ocr'

const FINALS: Record<string, string> = { 'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ' }
const NIQQUD = /[֑-ׇ]/

/** Normalize a single character: drop niqqud, fold Hebrew final letters, lowercase. */
function normChar(c: string): string {
  if (NIQQUD.test(c)) return ''
  return (FINALS[c] ?? c).toLowerCase()
}

export function normalize(s: string): string {
  let out = ''
  for (const c of s) out += normChar(c)
  return out.replace(/\s+/g, ' ').trim()
}

/**
 * Returns the indices of all words that participate in a match of `query`.
 * Matching is done per line on the joined text, so multi-word phrases work too.
 */
export function findMatches(words: OcrWord[], query: string): Set<number> {
  const q = normalize(query)
  const hits = new Set<number>()
  if (!q) return hits

  // Group word indices by line
  const lines = new Map<number, number[]>()
  words.forEach((w, i) => {
    const arr = lines.get(w.line)
    if (arr) arr.push(i)
    else lines.set(w.line, [i])
  })

  for (const idxs of lines.values()) {
    let joined = ''
    const owner: number[] = [] // owner[k] = word index of char k
    idxs.forEach((wi, n) => {
      if (n > 0) {
        joined += ' '
        owner.push(-1)
      }
      for (const c of words[wi].text) {
        const nc = normChar(c)
        for (const ch of nc) {
          joined += ch
          owner.push(wi)
        }
      }
    })
    let from = 0
    for (;;) {
      const at = joined.indexOf(q, from)
      if (at < 0) break
      for (let k = at; k < at + q.length; k++) if (owner[k] >= 0) hits.add(owner[k])
      from = at + 1
    }
  }
  return hits
}

/** Split text into plain / highlighted segments for rendering in the text panel. */
export function highlightSegments(text: string, query: string): { text: string; hit: boolean }[] {
  const q = normalize(query)
  if (!q) return [{ text, hit: false }]
  let norm = ''
  const map: number[] = [] // map[k] = start offset in original text of normalized char k
  let offset = 0
  for (const c of text) {
    const nc = /\s/.test(c) ? ' ' : normChar(c)
    for (const ch of nc) {
      norm += ch
      map.push(offset)
    }
    offset += c.length
  }
  map.push(text.length)
  const segs: { text: string; hit: boolean }[] = []
  let last = 0
  let from = 0
  for (;;) {
    const at = norm.indexOf(q, from)
    if (at < 0) break
    const start = map[at]
    const endIdx = at + q.length
    let end = map[endIdx] ?? text.length
    // swallow trailing niqqud belonging to the last matched letter
    while (end < text.length && NIQQUD.test(text[end])) end++
    if (start > last) segs.push({ text: text.slice(last, start), hit: false })
    segs.push({ text: text.slice(start, end), hit: true })
    last = end
    from = endIdx
  }
  if (last < text.length) segs.push({ text: text.slice(last), hit: false })
  return segs
}
