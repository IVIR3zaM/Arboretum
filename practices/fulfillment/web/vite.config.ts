/// <reference types="vitest" />
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      // See src/shims/node-fs.ts: the backend's snapshot/ERP-feed readers
      // import node:fs unconditionally; this keeps the production browser
      // bundle resolvable without touching backend source.
      "node:fs": fileURLToPath(new URL("./src/shims/node-fs.ts", import.meta.url)),
    },
  },
  define: {
    // Ditto for the env vars those readers branch on — bare `process` isn't
    // defined in a browser bundle.
    "process.env.ATP_SOURCE": "undefined",
    "process.env.ERP_FEED_DIR": "undefined",
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/setupTests.ts"],
  },
});
