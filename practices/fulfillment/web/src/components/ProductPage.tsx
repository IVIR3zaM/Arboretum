import { useEffect, useState } from "react";
import type { AvailabilityResult, CatalogItem, StoreClient } from "../client";
import { StockBadge } from "./StockBadge";

export interface CartLine {
  sku: string;
  qty: number;
}

type CheckoutState = "idle" | "loading" | "confirmed" | "rejected";

export function ProductPage({
  product,
  client,
  onAddToCart,
}: {
  product: CatalogItem;
  client: StoreClient;
  onAddToCart: (line: CartLine) => void;
}) {
  const [availability, setAvailability] = useState<AvailabilityResult | null>(null);
  const [qty, setQty] = useState(1);
  const [checkoutState, setCheckoutState] = useState<CheckoutState>("idle");

  useEffect(() => {
    let cancelled = false;
    setAvailability(null);
    setCheckoutState("idle");

    client.checkAvailability(product.sku, product.location).then((result) => {
      if (!cancelled) {
        setAvailability(result);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [client, product.sku, product.location]);

  const handleAddToCart = () => {
    onAddToCart({ sku: product.sku, qty });
  };

  const handleCheckout = async () => {
    setCheckoutState("loading");
    const requestId = `${product.sku}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const result = await client.confirmOrder({
      orderId: requestId,
      requestId,
      sku: product.sku,
      location: product.location,
      qty,
    });
    setCheckoutState(result.status === "confirmed" ? "confirmed" : "rejected");
  };

  return (
    <section className="product-page" aria-label={product.name}>
      <h2>{product.name}</h2>
      <StockBadge availability={availability} />

      <div className="qty-control">
        <label htmlFor="qty">Quantity</label>
        <input
          id="qty"
          type="number"
          min={1}
          value={qty}
          onChange={(event) => setQty(Math.max(1, Number(event.target.value) || 1))}
        />
      </div>

      <div className="actions">
        <button type="button" onClick={handleAddToCart}>
          Add to cart
        </button>
        <button type="button" onClick={handleCheckout} disabled={checkoutState === "loading"}>
          Checkout
        </button>
      </div>

      {checkoutState === "loading" && <p role="status">Placing order…</p>}
      {checkoutState === "confirmed" && <p role="status">Order confirmed</p>}
      {checkoutState === "rejected" && (
        <p role="status">Sorry — we can't fulfil that quantity right now.</p>
      )}
    </section>
  );
}
