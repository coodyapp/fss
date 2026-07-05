import { type CSSProperties } from "react"
import { Star } from "lucide-react"

import { SiteFooter } from "@/components/site-footer"
import { Terminal } from "@/components/terminal"

const INSTALL_CMD = "curl -fsSL https://fss.coody.app/install.sh | sh"
const VERSION = `v${import.meta.env.VITE_FSS_VERSION}`
const VERSION_STYLE = {
  "--version-width": `${VERSION.length}ch`,
} as CSSProperties

const LOGO = ` ███████████  █████████   █████████
░░███░░░░░░  ███░░░░░███ ███░░░░░███
 ░███ █ ░   ░███    ░░░ ░███    ░░░
 ░███████   ░░█████████ ░░█████████
 ░███░░░█    ░░░░░░░░███ ░░░░░░░░███
 ░███ ░      ███    ░███ ███    ░███
 █████      ░░█████████ ░░█████████
░░░░░        ░░░░░░░░░   ░░░░░░░░░  `

const USAGE_COMMANDS = [
  "fss scan .            # security + supply-chain scan",
  "fss clean ~/projects  # reclaim node_modules space",
  "fss outdated .        # flag stale dependencies",
  "fss --help",
]

export function App() {
  return (
    <>
      <div aria-hidden className="glitch-background" />
      <main className="relative z-10 mx-auto flex min-h-svh max-w-3xl flex-col gap-16 px-6 py-20 sm:py-28">
        <div className="flex flex-col gap-6">
          <pre className="animate-logo overflow-x-auto font-mono text-[0.6rem] leading-tight text-primary sm:text-xs">
            {LOGO}
          </pre>

          <div className="flex flex-col gap-4">
            <p className="font-mono text-xs tracking-wide text-muted-foreground uppercase">
              <span className="version-typewriter" style={VERSION_STYLE}>
                {VERSION}
              </span>
            </p>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
              A Fast Security Scan for developers.
            </h1>
            <p className="max-w-md text-lg text-muted-foreground">
              Scan Node.js projects for supply-chain attack indicators, clean{" "}
              <code>node_modules</code> safely, and flag outdated dependencies.
              One POSIX shell script, zero dependencies.
            </p>
            <a
              href="https://github.com/coodyapp/fss"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex w-fit items-center gap-2 rounded-md border border-red-500/25 bg-red-950/20 px-3 py-2 font-mono text-xs tracking-[0.14em] text-red-100 uppercase transition-colors hover:border-red-400/45 hover:bg-red-900/30"
            >
              <Star className="size-3.5 fill-current" />
              Star on GitHub
            </a>
          </div>
        </div>

        <Terminal id="install" commands={[INSTALL_CMD]} typewriter>
          Installs the <code>fss</code> CLI to <code>~/.fss</code> and links it
          into your <code>PATH</code>. Auditable in one sitting — read it
          before you run it.
        </Terminal>

        <Terminal commands={USAGE_COMMANDS} typewriter>
          Common commands after <code>fss</code> is installed.
        </Terminal>

        <section className="border-l-2 border-primary/40 pl-4 font-mono text-sm text-muted-foreground">
          <p>
            Runs on <strong className="text-foreground">macOS</strong> and{" "}
            <strong className="text-foreground">Debian-based Linux</strong>{" "}
            with nothing but POSIX <code>sh</code>, <code>grep</code> and{" "}
            <code>find</code> — the tool that checks your supply chain
            shouldn&apos;t add to it. Exit codes are CI-ready:{" "}
            <code>0</code> clean, <code>1</code> warnings, <code>2</code>{" "}
            critical.
          </p>
        </section>

        <SiteFooter />
      </main>
    </>
  )
}

export default App
