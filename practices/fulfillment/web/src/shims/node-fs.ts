// The backend's snapshot/ERP-feed readers import `node:fs` unconditionally
// (even though the default, non-"live" code path used by this storefront's
// in-process client never has to touch disk from the browser bundle). Vite
// can't bundle a real `node:fs` for the browser, so this alias (see
// vite.config.ts) stands in for it just so the module graph resolves.
export function readFileSync(): never {
  throw new Error("node:fs is unavailable in the browser bundle");
}
