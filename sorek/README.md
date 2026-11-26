# סורק — סורק חכם בזמן אמת

אפליקציית ווב לזיהוי טקסט (OCR) בעברית ובאנגלית, עם ממשק עברי מלא (RTL), מצב כהה ועיצוב שמותאם קודם כול לטלפון.

## סטטוס

| שלב | תכולה | מצב |
|---|---|---|
| 1 · MVP | העלאת תמונה (גרירה / בחירת קובץ / Ctrl+V), OCR מקומי heb+eng ב-Web Worker, חיפוש מילה עם הדגשה בזמן אמת | ✅ |
| 2 | מצלמה חיה עם סריקה רציפה | ⏳ |
| 3 | מצב "שאל": Claude דרך `/api/analyze` עם streaming | ⏳ |
| 4–10 | QR/ברקוד, מצב מסמך, תרגום, טבלאות→CSV, ייצוא, היסטוריה, PWA | ⏳ |

## סטאק

React + TypeScript + Vite · Tailwind CSS v4 · Framer Motion · Zustand · Tesseract.js 7

- **OCR מקומי לגמרי:** Tesseract רץ ב-Web Worker נפרד, כך שהממשק לא נתקע בזמן הסריקה. ה-worker, מנוע ה-WASM וקובצי השפה (`heb`, `eng` בגרסת `best_int` הקטנה) מגיעים מ-npm, ו-`scripts/copy-tesseract.mjs` מעתיק אותם ל-`public/tesseract/` בכל `npm install` / `dev` / `build`. כך אין תלות ב-CDN, וזה גם הבסיס לעבודה אופליין ב-PWA בהמשך.
- **חיפוש:** מתעלם מניקוד, מאחד אותיות סופיות (ך=כ, ם=מ…) ומאותיות גדולות/קטנות באנגלית. עובד גם על ביטויים של כמה מילים בתוך אותה שורה.

## הרצה מקומית

דרוש Node 20 ומעלה.

```bash
cd sorek
npm install
npm run dev        # http://localhost:5173
```

בנייה ובדיקה של גרסת הייצור:

```bash
npm run build
npm run preview
```

## פריסה ל-Vercel

1. ב-Vercel: **Add New → Project** ולבחור את הריפו.
2. **Root Directory:** `sorek` (חשוב: האפליקציה יושבת בתת-תיקייה).
3. Framework Preset: **Vite** (מזוהה אוטומטית). Build: `npm run build`, Output: `dist`.
4. Deploy.

> משלב 3 והלאה צריך להגדיר גם משתנה סביבה `ANTHROPIC_API_KEY` ב-**Settings → Environment Variables**. המפתח ישמש רק בצד השרת (`/api/analyze`) ולא ייחשף בדפדפן. בשלב 1 הוא לא נדרש.

## מבנה

```
sorek/
├── scripts/copy-tesseract.mjs   # מעתיק את נכסי Tesseract ל-public/
└── src/
    ├── App.tsx                  # פריסה + האזנה לגרירה/הדבקה
    ├── store.ts                 # מצב גלובלי (Zustand)
    ├── lib/ocr.ts               # Worker של Tesseract, טעינת תמונה, חילוץ מילים ותיבות
    ├── lib/scan.ts              # צינור: תמונה → OCR → store
    ├── lib/search.ts            # נרמול עברית וחיפוש מילים/ביטויים
    └── components/              # Header, DropZone, Viewer (תמונה+תיבות+קו סורק), SearchBar, TextPanel
```
