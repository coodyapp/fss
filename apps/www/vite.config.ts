import fs from "fs"
import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig, type Plugin } from "vite"

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

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), copyInstallScript()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  define: {
    "import.meta.env.VITE_FSS_VERSION": JSON.stringify(FSS_VERSION),
  },
})
