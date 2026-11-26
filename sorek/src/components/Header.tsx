export function Header() {
  return (
    <header className="flex items-center gap-3 px-4 pt-[max(env(safe-area-inset-top),1rem)] pb-3">
      <img src="/favicon.svg" alt="" className="size-9" />
      <div>
        <h1 className="text-xl font-bold leading-tight">סורק</h1>
        <p className="text-xs text-ink-400">סורק חכם בזמן אמת · עברית ואנגלית</p>
      </div>
    </header>
  )
}
