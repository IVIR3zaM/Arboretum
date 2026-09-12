import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { App } from "./App";
import type { StoreClient } from "./client";

function makeClient(): StoreClient {
  return {
    listCatalog: vi.fn().mockResolvedValue([
      { sku: "SKU-1001", name: "Trailhead Backpack 30L", location: "DC-WEST" },
      { sku: "SKU-1003", name: "Alpine Camp Stove", location: "DC-EAST" },
    ]),
    checkAvailability: vi.fn().mockResolvedValue({
      sku: "SKU-1001",
      location: "DC-WEST",
      atp: 5,
      inStock: true,
    }),
    confirmOrder: vi.fn().mockResolvedValue({
      orderId: "o1",
      status: "confirmed",
      sku: "SKU-1001",
      location: "DC-WEST",
      qty: 1,
    }),
  };
}

describe("App", () => {
  it("lists the catalog and shows the first product's detail via the injected client", async () => {
    render(<App client={makeClient()} />);

    expect(await screen.findByRole("button", { name: "Alpine Camp Stove" })).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Trailhead Backpack 30L" })
    ).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("In stock")).toBeInTheDocument());
  });

  it("switches the detail panel when a different product is selected", async () => {
    const client = makeClient();
    render(<App client={client} />);

    fireEvent.click(await screen.findByRole("button", { name: "Alpine Camp Stove" }));

    await waitFor(() =>
      expect(client.checkAvailability).toHaveBeenCalledWith("SKU-1003", "DC-EAST")
    );
    expect(screen.getByRole("heading", { name: "Alpine Camp Stove" })).toBeInTheDocument();
  });
});
