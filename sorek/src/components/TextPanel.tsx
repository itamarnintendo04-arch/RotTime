import { useMemo } from 'react'
import { motion } from 'framer-motion'
import { useScan } from '../store'
import { highlightSegments } from '../lib/search'

export function TextPanel() {
  const { result, query } = useScan()
  const segs = useMemo(() => (result ? highlightSegments(result.text, query) : []), [result, query])
  if (!result) return null

  return (
    <motion.section
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-3xl bg-ink-900 p-4 ring-1 ring-ink-700"
    >
      <div className="mb-3 flex items-center justify-between">
        <h2 className="font-semibold">הטקסט שזוהה</h2>
        <span className="text-xs text-ink-400">{result.words.length} מילים</span>
      </div>
      {result.text ? (
        <p dir="auto" className="whitespace-pre-wrap break-words leading-relaxed text-ink-200">
          {segs.map((s, i) => (s.hit ? <mark key={i} className="hit">{s.text}</mark> : <span key={i}>{s.text}</span>))}
        </p>
      ) : (
        <p className="text-ink-400">לא זוהה טקסט בתמונה.</p>
      )}
    </motion.section>
  )
}
