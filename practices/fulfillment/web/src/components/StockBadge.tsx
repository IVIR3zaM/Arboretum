import type { AvailabilityResult } from "../client";

export function StockBadge({ availability }: { availability: AvailabilityResult | null }) {
  if (!availability) {
    return null;
  }

  return (
    <span className={`stock-badge ${availability.inStock ? "in-stock" : "sold-out"}`}>
      {availability.inStock ? "In stock" : "Sold out"}
    </span>
  );
}
