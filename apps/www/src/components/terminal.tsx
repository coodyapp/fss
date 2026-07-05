import { type CSSProperties, type ReactNode, useState } from "react"
import { Check, Copy } from "lucide-react"
import { toast } from "sonner"

type TerminalProps = {
  commands: string[]
  id?: string
  typewriter?: boolean
  children?: ReactNode
}

export function Terminal({
  commands,
  id,
  typewriter = false,
  children,
}: TerminalProps) {
  const [copied, setCopied] = useState(false)

  const copyCommands = async () => {
    try {
      await navigator.clipboard.writeText(commands.join("\n"))
      setCopied(true)
      toast("Copied to clipboard")
      setTimeout(() => setCopied(false), 1500)
    } catch {
      toast("Could not copy commands")
    }
  }

  return (
    <section
      id={id}
      className="mx-auto flex w-full max-w-4xl scroll-mt-8 flex-col gap-3 sm:mt-0"
    >
      <div className="terminal-screen relative min-h-32 overflow-hidden rounded-[1rem] border border-emerald-900/55 bg-[#010604] text-left font-mono text-sm leading-6 text-emerald-100 shadow-[0_0_0_1px_rgba(18,230,140,0.08),0_0_45px_rgba(5,150,105,0.16)_inset,0_24px_70px_-28px_rgba(0,0,0,0.9)]">
        <div className="relative z-[1] flex items-center justify-between border-b border-emerald-900/40 px-4 py-2.5">
          <div className="flex items-center gap-3 font-mono text-[0.65rem] tracking-[0.22em] text-emerald-200/70 uppercase">
            <span className="relative flex size-2.5">
              <span className="absolute inline-flex size-full animate-ping rounded-full bg-emerald-500/50" />
              <span className="relative inline-flex size-2.5 rounded-full bg-emerald-500" />
            </span>
            <span>FSS CRT</span>
            <span className="hidden text-emerald-300/35 sm:inline">CH-01</span>
          </div>
          <div className="font-mono text-[0.65rem] tracking-[0.18em] text-emerald-300/45 uppercase">
            zsh feed
          </div>
        </div>
        <button
          type="button"
          onClick={copyCommands}
          className="absolute top-14 right-3 z-10 inline-flex h-7 items-center gap-1.5 rounded border border-emerald-500/25 bg-emerald-950/25 px-2.5 font-mono text-[0.65rem] tracking-[0.16em] text-emerald-200/70 uppercase transition-colors hover:border-emerald-400/45 hover:bg-emerald-900/35 hover:text-emerald-100"
        >
          {copied ? (
            <Check className="size-3.5 text-emerald-300" />
          ) : (
            <Copy className="size-3.5" />
          )}
          {copied ? "copied" : "copy"}
        </button>
        <div className="relative z-[1] flex flex-col gap-2.5 overflow-x-auto p-5 pr-20">
          {commands.map((command, index) => (
            <div
              key={`${command}-${index}`}
              className="flex w-max min-w-full gap-2.5"
            >
              <span
                aria-hidden
                className="shrink-0 text-emerald-500/80 select-none"
              >
                &gt;
              </span>
              {typewriter ? (
                <code className="terminal-command text-emerald-100 drop-shadow-[0_0_8px_rgba(18,230,140,0.35)]">
                  <span className="terminal-command-ghost">{command}</span>
                  <span
                    aria-hidden
                    className="terminal-typewriter"
                    style={
                      {
                        "--terminal-typewriter-delay": `${index * 0.7}s`,
                        "--terminal-typewriter-steps": Math.max(
                          command.length,
                          1
                        ),
                      } as CSSProperties
                    }
                  >
                    {command}
                  </span>
                </code>
              ) : (
                <code className="whitespace-pre text-emerald-100 drop-shadow-[0_0_8px_rgba(18,230,140,0.35)]">
                  {command}
                </code>
              )}
            </div>
          ))}
        </div>
      </div>
      {children ? (
        <p className="text-center font-mono text-sm text-muted-foreground">
          {children}
        </p>
      ) : null}
    </section>
  )
}
