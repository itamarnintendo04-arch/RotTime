import { createWorker, type Worker } from 'tesseract.js'

export interface OcrWord {
  text: string
  confidence: number
  bbox: { x0: number; y0: number; x1: number; y1: number }
  /** index of the line this word belongs to (for multi-word search) */
  line: number
}

export interface OcrResult {
  text: string
  words: OcrWord[]
  width: number
  height: number
}

export type ProgressFn = (status: string, progress: number) => void

let workerPromise: Promise<Worker> | null = null
let progressListener: ProgressFn | null = null

/**
 * Tesseract.js always runs recognition inside a dedicated Web Worker,
 * so the UI thread stays responsive. We keep a single warm worker.
 */
const asset = (p: string) => new URL(`${import.meta.env.BASE_URL}tesseract/${p}`, location.href).href
const INIT_TIMEOUT_MS = 60_000

export function getWorker(): Promise<Worker> {
  if (!workerPromise) {
    const init = createWorker(['heb', 'eng'], 1, {
      // All assets are self-hosted (copied from node_modules by scripts/copy-tesseract.mjs)
      workerPath: asset('worker.min.js'),
      corePath: asset('core/'),
      langPath: asset('lang'),
      logger: (m) => progressListener?.(m.status, m.progress ?? 0),
    })
    // If the worker script fails to load, Tesseract never settles — guard with a timeout.
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('OCR engine failed to load in time')), INIT_TIMEOUT_MS),
    )
    workerPromise = Promise.race([init, timeout]).catch((err) => {
      workerPromise = null
      init.then((w) => w.terminate()).catch(() => {})
      throw err
    })
  }
  return workerPromise
}

const MAX_SIDE = 2200

/** Load any image source into a canvas, downscaling very large photos for speed. */
export async function toCanvas(src: Blob): Promise<HTMLCanvasElement> {
  const bitmap = await createImageBitmap(src)
  const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
  const canvas = document.createElement('canvas')
  canvas.width = Math.round(bitmap.width * scale)
  canvas.height = Math.round(bitmap.height * scale)
  const ctx = canvas.getContext('2d')!
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  bitmap.close()
  return canvas
}

export async function recognize(canvas: HTMLCanvasElement, onProgress?: ProgressFn): Promise<OcrResult> {
  progressListener = onProgress ?? null
  try {
    const worker = await getWorker()
    const { data } = await worker.recognize(canvas, {}, { text: true, blocks: true })
    const words: OcrWord[] = []
    let line = 0
    for (const block of data.blocks ?? []) {
      for (const para of block.paragraphs) {
        for (const l of para.lines) {
          for (const w of l.words) {
            const text = w.text.trim()
            if (!text || w.confidence < 25) continue
            words.push({ text, confidence: w.confidence, bbox: w.bbox, line })
          }
          line++
        }
      }
    }
    return { text: data.text.trim(), words, width: canvas.width, height: canvas.height }
  } finally {
    progressListener = null
  }
}
