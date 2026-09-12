import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { StockBadge } from "./StockBadge";

describe("StockBadge", () => {
  it("renders 'In stock' when the availability result says inStock", () => {
    render(
      <StockBadge availability={{ sku: "SKU-1001", location: "DC-WEST", atp: 5, inStock: true }} />
    );
    expect(screen.getByText("In stock")).toBeInTheDocument();
  });

  it("renders 'Sold out' when the availability result says not inStock", () => {
    render(
      <StockBadge availability={{ sku: "SKU-1001", location: "DC-WEST", atp: 0, inStock: false }} />
    );
    expect(screen.getByText("Sold out")).toBeInTheDocument();
  });

  it("renders nothing when there is no availability result yet", () => {
    const { container } = render(<StockBadge availability={null} />);
    expect(container).toBeEmptyDOMElement();
  });
});
