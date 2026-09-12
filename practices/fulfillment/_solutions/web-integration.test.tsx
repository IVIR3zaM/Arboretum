// HIDDEN grader (examiner-only — never shipped to the learner's clone). Drives
// the REAL storefront (`web/src/App.tsx`) against the REAL backend
// (`web/src/client.ts`'s `backendClient`, wrapping the actual in-process
// `availability`/`orders` modules — no mocks, no fakes) with the resolver
// pointed at the live ERP feed. Run via `_solutions/vitest.web.config.ts`
// (NOT `web/vite.config.ts` — see that config's own comment for why).
//
// ATP_SOURCE / ERP_FEED_DIR are set by `_solutions/vitest.web.config.ts`'s
// `test.env` (a transformed test file's `import.meta.url` isn't a real
// `file:` URL, so this file can't compute the absolute feed path itself —
// the config's own `import.meta.url`, loaded directly by Node, can).

import { describe, expect, it } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { App } from "../web/src/App.tsx";
import { backendClient } from "../web/src/client.ts";

async function selectProduct(name: string) {
  fireEvent.click(await screen.findByRole("button", { name }));
}

async function checkout(qty: number) {
  const qtyInput = await screen.findByLabelText("Quantity");
  fireEvent.change(qtyInput, { target: { value: String(qty) } });
  fireEvent.click(screen.getByRole("button", { name: "Checkout" }));
}

describe("storefront checkout vs. live ATP (real backend, real ERP feed)", () => {
  it("rejects an order for a contended SKU that exceeds true ATP (no oversell)", async () => {
    render(<App client={backendClient} />);

    // SKU-1002: true ATP is 22 (on_hand 40, reserved 12, allocated 6). The
    // buggy live branch reports on_hand (40) as if it were ATP, so a qty-30
    // checkout would be wrongly confirmed pre-fix.
    await selectProduct("Ridgeline Sleeping Bag");
    await checkout(30);

    const status = await screen.findByText(
      "Sorry — we can't fulfil that quantity right now."
    );
    expect(status).toBeInTheDocument();
    expect(status.getAttribute("role")).toBe("status");
    expect(screen.queryByText("Order confirmed")).not.toBeInTheDocument();
  });

  it("confirms an order for a promisable SKU within true ATP", async () => {
    render(<App client={backendClient} />);

    // SKU-1001: never-reserved seed, true ATP 50, promisable both pre- and
    // post-fix — a sanity check that the gate isn't just failing everything.
    await selectProduct("Trailhead Backpack 30L");
    await checkout(10);

    await waitFor(() => {
      expect(screen.getByText("Order confirmed")).toBeInTheDocument();
    });
  });
});
