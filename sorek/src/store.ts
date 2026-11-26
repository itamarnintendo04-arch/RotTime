import { create } from 'zustand'
import type { OcrResult } from './lib/ocr'

export type Phase = 'idle' | 'loading' | 'scanning' | 'done' | 'error'

interface ScanState {
  imageUrl: string | null
  phase: Phase
  progress: number
  status: string
  result: OcrResult | null
  error: string | null
  query: string
  setImage: (url: string) => void
  setProgress: (status: string, progress: number) => void
  setResult: (r: OcrResult) => void
  setError: (e: string) => void
  setQuery: (q: string) => void
  reset: () => void
}

export const useScan = create<ScanState>((set, get) => ({
  imageUrl: null,
  phase: 'idle',
  progress: 0,
  status: '',
  result: null,
  error: null,
  query: '',
  setImage: (url) => {
    const prev = get().imageUrl
    if (prev) URL.revokeObjectURL(prev)
    set({ imageUrl: url, phase: 'loading', progress: 0, status: '', result: null, error: null })
  },
  setProgress: (status, progress) =>
    set({ status, progress, phase: status === 'recognizing text' ? 'scanning' : 'loading' }),
  setResult: (result) => set({ result, phase: 'done', progress: 1 }),
  setError: (error) => set({ error, phase: 'error' }),
  setQuery: (query) => set({ query }),
  reset: () => {
    const prev = get().imageUrl
    if (prev) URL.revokeObjectURL(prev)
    set({ imageUrl: null, phase: 'idle', progress: 0, status: '', result: null, error: null })
  },
}))
