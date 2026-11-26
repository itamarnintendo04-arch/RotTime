import { useRef } from 'react'
import { motion } from 'framer-motion'
import { isImage, scanImage } from '../lib/scan'

export function DropZone({ dragging }: { dragging: boolean }) {
  const input = useRef<HTMLInputElement>(null)
  return (
    <motion.button
      type="button"
      onClick={() => input.current?.click()}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0, scale: dragging ? 1.02 : 1 }}
      className={`group relative flex w-full flex-col items-center justify-center gap-4 overflow-hidden rounded-3xl border-2 border-dashed px-6 py-14 text-center transition-colors ${
        dragging ? 'border-accent bg-accent/10' : 'border-ink-600 bg-ink-900 hover:border-accent/60'
      }`}
    >
      <div className="grid size-16 place-items-center rounded-2xl bg-accent/15 text-accent">
        <svg viewBox="0 0 24 24" className="size-8" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
          <path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2" />
          <path d="M12 8v8M8 12h8" />
        </svg>
      </div>
      <div>
        <p className="text-lg font-semibold">
          <span className="hidden sm:inline">גררו תמונה לכאן</span>
          <span className="sm:hidden">בחרו תמונה לסריקה</span>
        </p>
        <p className="mt-1 text-sm text-ink-400">
          <span className="sm:hidden">מהגלריה או מהמצלמה</span>
          <span className="hidden sm:inline">
            או לחצו לבחירת קובץ · אפשר גם להדביק עם <kbd className="rounded bg-ink-700 px-1.5 py-0.5 font-sans text-xs">Ctrl+V</kbd>
          </span>
        </p>
      </div>
      <input
        ref={input}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0]
          if (isImage(f)) scanImage(f)
          e.target.value = ''
        }}
      />
    </motion.button>
  )
}
