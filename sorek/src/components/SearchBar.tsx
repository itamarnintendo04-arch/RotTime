import { useMemo } from 'react'
import { useScan } from '../store'
import { findMatches } from '../lib/search'

export function SearchBar() {
  const { query, setQuery, result, phase } = useScan()
  const count = useMemo(() => (result && query ? findMatches(result.words, query).size : 0), [result, query])
  const ready = phase === 'done'

  return (
    <div className="sticky top-0 z-10 -mx-4 bg-ink-950/85 px-4 py-3 backdrop-blur">
      <div className="flex items-center gap-2 rounded-2xl bg-ink-800 px-4 ring-1 ring-ink-700 focus-within:ring-2 focus-within:ring-accent">
        <svg viewBox="0 0 24 24" className="size-5 shrink-0 text-ink-400" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        <input
          type="text"
          enterKeyHint="search"
          dir="auto"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={ready ? 'חפשו מילה בתמונה…' : 'החיפוש יופעל אחרי הסריקה'}
          className="h-12 w-full bg-transparent text-base outline-none placeholder:text-ink-400"
          aria-label="חיפוש בתמונה"
        />
        {query && (
          <button
            type="button"
            onClick={() => setQuery('')}
            aria-label="נקה חיפוש"
            className="grid size-7 shrink-0 place-items-center rounded-full text-ink-400 hover:bg-ink-700 hover:text-white"
          >
            <svg viewBox="0 0 24 24" className="size-4" fill="none" stroke="currentColor" strokeWidth={2.5} strokeLinecap="round"><path d="M6 6l12 12M18 6 6 18" /></svg>
          </button>
        )}
        {query && ready && (
          <span className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs tabular-nums ${count ? 'bg-hit/20 text-hit' : 'bg-ink-700 text-ink-400'}`}>
            {count ? `${count} ${count === 1 ? 'מילה' : 'מילים'}` : 'לא נמצא'}
          </span>
        )}
      </div>
    </div>
  )
}
