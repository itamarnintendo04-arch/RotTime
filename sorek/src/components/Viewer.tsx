import { useMemo } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useScan } from '../store'
import { findMatches } from '../lib/search'

const STATUS_HE: Record<string, string> = {
  'loading tesseract core': 'טוען מנוע זיהוי…',
  'initializing tesseract': 'מאתחל…',
  'loading language traineddata': 'טוען מילוני עברית ואנגלית…',
  'initializing api': 'מכין…',
  'recognizing text': 'סורק טקסט…',
}

export function Viewer() {
  const { imageUrl, phase, progress, status, result, query, error } = useScan()
  const hits = useMemo(() => (result ? findMatches(result.words, query) : new Set<number>()), [result, query])
  const busy = phase === 'loading' || phase === 'scanning'
  if (!imageUrl) return null

  return (
    <div className="relative overflow-hidden rounded-3xl bg-ink-900 ring-1 ring-ink-700">
      <div className="relative mx-auto w-fit">
        <img src={imageUrl} alt="התמונה שנסרקה" className="block max-h-[60vh] w-auto max-w-full" />

        {result && (
          <svg
            viewBox={`0 0 ${result.width} ${result.height}`}
            preserveAspectRatio="none"
            className="pointer-events-none absolute inset-0 size-full"
          >
            {result.words.map((w, i) => {
              const hit = hits.has(i)
              if (query && !hit) return null
              const pad = Math.max(2, (w.bbox.y1 - w.bbox.y0) * 0.12)
              return (
                <motion.rect
                  key={i}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ duration: 0.15 }}
                  x={w.bbox.x0 - pad}
                  y={w.bbox.y0 - pad}
                  width={w.bbox.x1 - w.bbox.x0 + pad * 2}
                  height={w.bbox.y1 - w.bbox.y0 + pad * 2}
                  rx={pad * 1.5}
                  className={hit ? 'fill-hit/35 stroke-hit' : 'fill-accent/10 stroke-accent/50'}
                  strokeWidth={hit ? 3 : 1.5}
                  vectorEffect="non-scaling-stroke"
                />
              )
            })}
          </svg>
        )}

        <AnimatePresence>
          {busy && (
            <motion.div
              key="scan"
              className="pointer-events-none absolute inset-0"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              <div className="absolute inset-0 bg-ink-950/30" />
              <motion.div
                className="absolute inset-x-0 h-24 bg-gradient-to-b from-transparent via-accent/25 to-accent/60"
                style={{ boxShadow: '0 6px 20px -4px var(--color-accent)' }}
                initial={{ top: '-6rem' }}
                animate={{ top: ['-6rem', '100%'] }}
                transition={{ duration: 1.6, repeat: Infinity, ease: 'easeInOut', repeatType: 'reverse' }}
              >
                <div className="absolute inset-x-0 bottom-0 h-0.5 bg-accent" />
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {busy && (
          <motion.div
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 20, opacity: 0 }}
            className="absolute inset-x-3 bottom-3 rounded-2xl bg-ink-900/85 px-4 py-3 backdrop-blur"
          >
            <div className="mb-2 flex justify-between text-sm">
              <span>{STATUS_HE[status] ?? 'מכין…'}</span>
              {phase === 'scanning' && <span className="tabular-nums text-ink-400">{Math.round(progress * 100)}%</span>}
            </div>
            <div className="h-1.5 overflow-hidden rounded-full bg-ink-700">
              <motion.div
                className="h-full rounded-full bg-accent"
                animate={{ width: `${phase === 'scanning' ? Math.max(4, progress * 100) : 15}%` }}
              />
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {phase === 'error' && (
        <div className="absolute inset-x-3 bottom-3 rounded-2xl bg-red-950/90 px-4 py-3 text-sm text-red-200">{error}</div>
      )}
    </div>
  )
}
