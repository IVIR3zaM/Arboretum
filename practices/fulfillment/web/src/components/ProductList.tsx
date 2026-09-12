import type { CatalogItem } from "../client";

export function ProductList({
  products,
  selectedSku,
  onSelect,
}: {
  products: CatalogItem[];
  selectedSku: string | null;
  onSelect: (sku: string) => void;
}) {
  return (
    <ul className="product-list">
      {products.map((product) => (
        <li key={product.sku}>
          <button
            type="button"
            aria-pressed={product.sku === selectedSku}
            onClick={() => onSelect(product.sku)}
          >
            {product.name}
          </button>
        </li>
      ))}
    </ul>
  );
}
