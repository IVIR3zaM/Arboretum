import { useEffect, useState } from "react";
import { backendClient } from "./client";
import type { CatalogItem, StoreClient } from "./client";
import { ProductList } from "./components/ProductList";
import { ProductPage, type CartLine } from "./components/ProductPage";

export function App({ client = backendClient }: { client?: StoreClient }) {
  const [catalog, setCatalog] = useState<CatalogItem[]>([]);
  const [selectedSku, setSelectedSku] = useState<string | null>(null);
  const [cart, setCart] = useState<CartLine[]>([]);

  useEffect(() => {
    client.listCatalog().then((items) => {
      setCatalog(items);
      setSelectedSku((current) => current ?? items[0]?.sku ?? null);
    });
  }, [client]);

  const selectedProduct = catalog.find((product) => product.sku === selectedSku) ?? null;

  const handleAddToCart = (line: CartLine) => {
    setCart((prev) => {
      const existing = prev.find((entry) => entry.sku === line.sku);
      if (existing) {
        return prev.map((entry) =>
          entry.sku === line.sku ? { ...entry, qty: entry.qty + line.qty } : entry
        );
      }
      return [...prev, line];
    });
  };

  const cartCount = cart.reduce((sum, line) => sum + line.qty, 0);

  return (
    <main className="storefront">
      <header>
        <h1>Trailhead Outfitters</h1>
        <p className="cart-summary">
          Cart: {cartCount} item{cartCount === 1 ? "" : "s"}
        </p>
      </header>
      <div className="layout">
        <ProductList products={catalog} selectedSku={selectedSku} onSelect={setSelectedSku} />
        {selectedProduct && (
          <ProductPage
            key={selectedProduct.sku}
            product={selectedProduct}
            client={client}
            onAddToCart={handleAddToCart}
          />
        )}
      </div>
    </main>
  );
}
