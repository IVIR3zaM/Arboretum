import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { StoreClient } from "../client";
import { ProductPage } from "./ProductPage";

const product = { sku: "SKU-1001", name: "Trailhead Backpack 30L", location: "DC-WEST" };

function makeClient(overrides: Partial<StoreClient> = {}): StoreClient {
  return {
    listCatalog: vi.fn().mockResolvedValue([]),
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
    ...overrides,
  };
}

describe("ProductPage", () => {
  it("shows the product's name and its stock badge", async () => {
    render(<ProductPage product={product} client={makeClient()} onAddToCart={() => {}} />);

    expect(screen.getByRole("heading", { name: "Trailhead Backpack 30L" })).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("In stock")).toBeInTheDocument());
  });

  it("shows a sold-out badge when the client reports no availability", async () => {
    const client = makeClient({
      checkAvailability: vi.fn().mockResolvedValue({
        sku: "SKU-1001",
        location: "DC-WEST",
        atp: 0,
        inStock: false,
      }),
    });
    render(<ProductPage product={product} client={client} onAddToCart={() => {}} />);

    await waitFor(() => expect(screen.getByText("Sold out")).toBeInTheDocument());
  });

  it("calls onAddToCart with the selected sku and quantity", async () => {
    const onAddToCart = vi.fn();
    render(<ProductPage product={product} client={makeClient()} onAddToCart={onAddToCart} />);
    await waitFor(() => expect(screen.getByText("In stock")).toBeInTheDocument());

    fireEvent.click(screen.getByRole("button", { name: "Add to cart" }));

    expect(onAddToCart).toHaveBeenCalledWith({ sku: "SKU-1001", qty: 1 });
  });

  it("shows a success message when checkout confirms the order", async () => {
    const client = makeClient();
    render(<ProductPage product={product} client={client} onAddToCart={() => {}} />);

    fireEvent.click(screen.getByRole("button", { name: "Checkout" }));

    await waitFor(() => expect(screen.getByText("Order confirmed")).toBeInTheDocument());
    expect(client.confirmOrder).toHaveBeenCalledWith(
      expect.objectContaining({ sku: "SKU-1001", location: "DC-WEST", qty: 1 })
    );
  });

  it("shows a rejection message when checkout rejects the order", async () => {
    const client = makeClient({
      confirmOrder: vi.fn().mockResolvedValue({
        orderId: "o1",
        status: "rejected",
        sku: "SKU-1001",
        location: "DC-WEST",
        qty: 1,
      }),
    });
    render(<ProductPage product={product} client={client} onAddToCart={() => {}} />);

    fireEvent.click(screen.getByRole("button", { name: "Checkout" }));

    await waitFor(() =>
      expect(
        screen.getByText("Sorry — we can't fulfil that quantity right now.")
      ).toBeInTheDocument()
    );
  });
});
