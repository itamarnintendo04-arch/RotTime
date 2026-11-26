import { recognize, toCanvas } from './ocr'
import { useScan } from '../store'

let runId = 0

/** Run the full pipeline for one image: preview → canvas → OCR in worker → store. */
export async function scanImage(file: Blob) {
  const id = ++runId
  const s = useScan.getState()
  s.setImage(URL.createObjectURL(file))
  try {
    const canvas = await toCanvas(file)
    const result = await recognize(canvas, (status, p) => {
      if (id === runId) useScan.getState().setProgress(status, p)
    })
    if (id === runId) useScan.getState().setResult(result)
  } catch (err) {
    console.error(err)
    if (id === runId) useScan.getState().setError('לא הצלחנו לקרוא את התמונה. נסו תמונה אחרת.')
  }
}

export function isImage(f: File | Blob | null | undefined): f is Blob {
  return !!f && f.type.startsWith('image/')
}
