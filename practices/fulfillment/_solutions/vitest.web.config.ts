// HIDDEN grader config (examiner-only). Deliberately SEPARATE from
// `web/vite.config.ts`: that config aliases `node:fs` to a throwing shim and
// `define`s `process.env.ATP_SOURCE` / `process.env.ERP_FEED_DIR` to
// `undefined` so the browser bundle resolves — which would make it impossible
// for this integration test to ever reach the live/ERP-feed code path. This
// config has NO `node:fs` alias and NO `process.env` define, so the real
// backend (reading the real feed off disk) runs unmodified under the test.
//
// `root` points at `web/` so the project's own node_modules (react,
// react-dom, @testing-library/*) resolve normally; `test.include` points at
// this file's sibling integration test via an absolute path, since it lives
// outside `root`.
//
// Deliberately does NOT `import { defineConfig } from "vite"` or
// `@vitejs/plugin-react`: this file lives in `_solutions/`, a sibling of
// `web/` with no node_modules of its own and no common ancestor node_modules
// to fall back to, so a bare-specifier `require`/`import` of a package that
// is only installed under `web/node_modules` cannot resolve from here.
// Sticking to a plain exported config object (no vite helper, no plugin)
// avoids that resolution trap entirely; Vite's own default esbuild
// transform already handles `.tsx` JSX without the React plugin, which only
// adds Fast Refresh — irrelevant for a one-shot test run.

// The integration test itself (like this config) lives in `_solutions/`,
// outside `web/`, so its OWN bare imports (as opposed to `web/src/*`'s bare
// imports, which resolve fine relative to their own in-tree location) can't
// walk up to `web/node_modules` on their own. `@testing-library/react` is the
// one such import the test file uses directly, so it gets an explicit alias
// resolved via `createRequire` anchored at `web/package.json` — i.e. "resolve
// this exactly as web/ itself would".

/// <reference types="vitest" />
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const webRoot = fileURLToPath(new URL("../web/", import.meta.url));
const integrationTest = fileURLToPath(new URL("./web-integration.test.tsx", import.meta.url));
const requireFromWeb = createRequire(fileURLToPath(new URL("../web/package.json", import.meta.url)));
const erpFeedDir = fileURLToPath(new URL("../reference/infra/erp-availability/", import.meta.url));

export default {
  root: webRoot,
  // web/src/*.tsx (and this integration test) write JSX with no explicit
  // `import React from "react"`, relying on the automatic JSX runtime that
  // `@vitejs/plugin-react` normally configures. Since this config skips that
  // plugin (see the resolution-trap comment above), tell Vite's built-in
  // esbuild transform to use the automatic runtime directly instead.
  esbuild: {
    jsx: "automatic",
  },
  resolve: {
    alias: {
      "@testing-library/react": requireFromWeb.resolve("@testing-library/react"),
      "react/jsx-dev-runtime": requireFromWeb.resolve("react/jsx-dev-runtime"),
      "react/jsx-runtime": requireFromWeb.resolve("react/jsx-runtime"),
      "react-dom/client": requireFromWeb.resolve("react-dom/client"),
      "react-dom": requireFromWeb.resolve("react-dom"),
      react: requireFromWeb.resolve("react"),
    },
  },
  test: {
    root: webRoot,
    environment: "jsdom",
    globals: true,
    include: [integrationTest],
    setupFiles: [fileURLToPath(new URL("../web/src/setupTests.ts", import.meta.url))],
    // Vite/Vitest rewrites `import.meta.url` inside a transformed test file
    // to a non-`file:` module id, so `fileURLToPath` can't be used THERE to
    // locate the reference feed. This config's own `import.meta.url` (loaded
    // directly by Node, not through Vite's module graph) is a real file URL,
    // so the absolute feed path is computed once here and handed to the test
    // process via `test.env`, alongside pointing the resolver at the live
    // ERP feed instead of the local snapshot.
    env: {
      ATP_SOURCE: "live",
      ERP_FEED_DIR: erpFeedDir,
    },
  },
};
