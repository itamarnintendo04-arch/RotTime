// Copies the Tesseract worker, WASM core and heb/eng language data into public/
// so OCR is fully self-hosted (no CDN, works offline once cached by the PWA).
import { cpSync, mkdirSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const nm = join(root, 'node_modules')
const out = join(root, 'public', 'tesseract')
mkdirSync(join(out, 'core'), { recursive: true })
mkdirSync(join(out, 'lang'), { recursive: true })

cpSync(join(nm, 'tesseract.js/dist/worker.min.js'), join(out, 'worker.min.js'))
for (const f of readdirSync(join(nm, 'tesseract.js-core'))) {
  if (f.endsWith('lstm.wasm.js')) cpSync(join(nm, 'tesseract.js-core', f), join(out, 'core', f))
}
for (const lang of ['heb', 'eng']) {
  cpSync(join(nm, `@tesseract.js-data/${lang}/4.0.0_best_int/${lang}.traineddata.gz`), join(out, 'lang', `${lang}.traineddata.gz`))
}
console.log('tesseract assets copied to public/tesseract')
