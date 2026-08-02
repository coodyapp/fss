import { execFileSync } from "child_process"
import fs from "fs"
import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig, type Plugin } from "vite"

const SITE_ORIGIN = "https://fss.coody.app"

// Single source of truth for the version shown on the site:
// FSS_VERSION in apps/cli/lib/common.sh.
const fssCommon = fs.readFileSync(
  path.resolve(__dirname, "../cli/lib/common.sh"),
  "utf-8",
)
const fssVersionMatch = fssCommon.match(/FSS_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"/)
if (!fssVersionMatch) {
  throw new Error("Could not find FSS_VERSION in apps/cli/lib/common.sh")
}
const FSS_VERSION = fssVersionMatch[1]

// Ships the repo-root install.sh as a static asset so
// `curl -fsSL https://fss.coody.app/install.sh | sh` works.
function copyInstallScript(): Plugin {
  return {
    name: "copy-install-script",
    closeBundle() {
      fs.copyFileSync(
        path.resolve(__dirname, "../../install.sh"),
        path.resolve(__dirname, "dist/install.sh"),
      )
    },
  }
}

// Generates sitemap.xml at build time so <lastmod> tracks the commit being
// published, instead of rotting in a hand-maintained file. robots.txt (in
// public/) points crawlers at it.
function emitSitemap(): Plugin {
  return {
    name: "emit-sitemap",
    closeBundle() {
      let lastmod = ""
      try {
        // %cs = committer date, YYYY-MM-DD. Works with a depth-1 checkout.
        lastmod = execFileSync("git", ["log", "-1", "--format=%cs"], {
          cwd: __dirname,
          encoding: "utf-8",
        }).trim()
      } catch {
        // No git (tarball build, sandbox) — fall back to the build date.
      }
      if (!/^\d{4}-\d{2}-\d{2}$/.test(lastmod)) {
        lastmod = new Date().toISOString().slice(0, 10)
      }

      const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${SITE_ORIGIN}/</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
`
      fs.writeFileSync(path.resolve(__dirname, "dist/sitemap.xml"), sitemap)
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), copyInstallScript(), emitSitemap()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  define: {
    "import.meta.env.VITE_FSS_VERSION": JSON.stringify(FSS_VERSION),
  },
})
