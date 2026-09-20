import { defineConfig } from "vite";

// GitHub Pages serves project sites under /<repo>/, so the base must match.
// Override with BASE_PATH for local/preview if needed.
export default defineConfig({
  base: process.env.BASE_PATH ?? "/clueweave/",
  build: {
    target: "es2022",
    outDir: "dist",
  },
});
