import coodyLogo from "@/assets/coody-logo-white.png"

export function SiteFooter() {
  return (
    <footer className="relative w-full overflow-hidden">
      <div className="relative z-10 mx-auto flex max-w-screen-xl flex-col items-center gap-2 px-4 py-16 text-center md:px-8">
        <p className="text-[11px] font-medium tracking-[0.25em] text-gray-500 uppercase">
          Powered by
        </p>
        <a
          href="https://coody.app"
          target="_blank"
          rel="noopener noreferrer"
          className="opacity-90 transition-opacity duration-300 hover:opacity-100"
        >
          <img src={coodyLogo} alt="Coody" className="h-9 w-auto" />
        </a>
      </div>
    </footer>
  )
}
