import { useEffect, useState } from 'react'
import { Header } from './components/Header'
import { DropZone } from './components/DropZone'
import { Viewer } from './components/Viewer'
import { SearchBar } from './components/SearchBar'
import { TextPanel } from './components/TextPanel'
import { useScan } from './store'
import { getWorker } from './lib/ocr'
import { isImage, scanImage } from './lib/scan'

export default function App() {
  const imageUrl = useScan((s) => s.imageUrl)
  const reset = useScan((s) => s.reset)
  const [dragging, setDragging] = useState(false)

  useEffect(() => {
    // Warm up the OCR worker in the background so the first scan is faster.
    const t = setTimeout(() => getWorker().catch(() => {}), 300)

    const onPaste = (e: ClipboardEvent) => {
      const item = [...(e.clipboardData?.items ?? [])].find((i) => i.type.startsWith('image/'))
      const file = item?.getAsFile()
      if (isImage(file)) {
        e.preventDefault()
        scanImage(file)
      }
    }
    let depth = 0
    const onEnter = (e: DragEvent) => {
      if (!e.dataTransfer?.types.includes('Files')) return
      depth++
      setDragging(true)
    }
    const onLeave = () => {
      depth = Math.max(0, depth - 1)
      if (!depth) setDragging(false)
    }
    const onOver = (e: DragEvent) => e.preventDefault()
    const onDrop = (e: DragEvent) => {
      e.preventDefault()
      depth = 0
      setDragging(false)
      const f = [...(e.dataTransfer?.files ?? [])].find(isImage)
      if (f) scanImage(f)
    }
    window.addEventListener('paste', onPaste)
    window.addEventListener('dragenter', onEnter)
    window.addEventListener('dragleave', onLeave)
    window.addEventListener('dragover', onOver)
    window.addEventListener('drop', onDrop)
    return () => {
      clearTimeout(t)
      window.removeEventListener('paste', onPaste)
      window.removeEventListener('dragenter', onEnter)
      window.removeEventListener('dragleave', onLeave)
      window.removeEventListener('dragover', onOver)
      window.removeEventListener('drop', onDrop)
    }
  }, [])

  return (
    <div className="mx-auto flex min-h-dvh max-w-5xl flex-col">
      <Header />
      <main className="flex-1 px-4 pb-[max(env(safe-area-inset-bottom),1.5rem)]">
        {!imageUrl ? (
          <DropZone dragging={dragging} />
        ) : (
          <div className="flex flex-col gap-4 lg:grid lg:grid-cols-[minmax(0,1fr)_22rem] lg:items-start">
            <div className="flex flex-col gap-3">
              <SearchBar />
              <Viewer />
              <button
                onClick={reset}
                className="self-start rounded-xl bg-ink-800 px-4 py-2 text-sm ring-1 ring-ink-700 hover:bg-ink-700"
              >
                ← תמונה חדשה
              </button>
            </div>
            <TextPanel />
          </div>
        )}
      </main>
    </div>
  )
}
