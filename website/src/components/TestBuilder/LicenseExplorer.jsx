import React, { useMemo, useState } from "react";
import { Button, Dialog, Input, RadioCards } from "./ui";
import styles from "./styles.module.css";

// Browse Microsoft's licensing reference both ways: a product and the service plans inside it, or a service
// plan and the products that include it. Only a service plan can be picked, because that is what a test checks.
//
// catalog: { products: [[name, stringId, guid]], plans: [[name, friendly, guids, productIndexes]] }
export const planLabel = (plan) => (plan.friendly ? plan.friendly + " (" + plan.name + ")" : plan.name);

export function indexCatalog(catalog) {
  const products = catalog.products.map(([name, stringId, guid], index) => ({ index, name, stringId, guid, plans: [] }));
  const plans = catalog.plans.map(([name, friendly, guids, productIndexes]) => {
    const plan = { name, friendly, guids, products: productIndexes.map((i) => products[i]) };
    plan.products.forEach((p) => p.plans.push(plan));
    plan.search = (name + " " + friendly + " " + guids.join(" ")).toLowerCase();
    return plan;
  });
  products.forEach((p) => {
    p.plans.sort((a, b) => planLabel(a).localeCompare(planLabel(b)));
    p.search = (p.name + " " + p.stringId + " " + p.guid).toLowerCase();
  });
  products.sort((a, b) => a.name.localeCompare(b.name));
  plans.sort((a, b) => planLabel(a).localeCompare(planLabel(b)));
  return { products, plans, planByName: Object.fromEntries(plans.map((p) => [p.name, p])) };
}

export default function LicenseExplorer({ open, onOpenChange, index, selected, onAdd, onRemove }) {
  const [view, setView] = useState("product");
  const [query, setQuery] = useState("");
  const [product, setProduct] = useState(null);
  const [plan, setPlan] = useState(null);
  const q = query.trim().toLowerCase();

  const productList = useMemo(() => (q ? index.products.filter((p) => p.search.includes(q) || p.plans.some((s) => s.search.includes(q))) : index.products), [q, index]);
  const planList = useMemo(() => (q ? index.plans.filter((s) => s.search.includes(q) || s.products.some((p) => p.search.includes(q))) : index.plans), [q, index]);

  const showProduct = (p) => {
    setView("product");
    setProduct(p);
  };
  const showPlan = (s) => {
    setView("plan");
    setPlan(s);
  };
  const pick = (s) =>
    selected.includes(s.name) ? (
      <Button size="xs" onClick={() => onRemove(s.name)}>
        Added. Remove
      </Button>
    ) : (
      <Button size="xs" variant="primary" onClick={() => onAdd(s.name)}>
        Add
      </Button>
    );

  return (
    <Dialog open={open} onOpenChange={onOpenChange} title="Licence explorer" description="Find the service plan a test needs. Start from a product you know, such as Microsoft 365 E5, or from the service plan itself.">
      <div className={styles.explorerBar}>
        <RadioCards
          label="Browse by"
          columns
          value={view}
          onValueChange={setView}
          options={[
            { value: "product", label: "By product", text: "Pick a product, then a service plan inside it." },
            { value: "plan", label: "By service plan", text: "Pick a service plan and see which products include it." },
          ]}
        />
        <Input type="search" aria-label="Search" placeholder="Search products and service plans by name, string ID or GUID" value={query} onChange={(e) => setQuery(e.target.value)} />
      </div>
      <div className={styles.explorer}>
        <ul className={styles.explorerList} aria-label={view === "product" ? "Products" : "Service plans"}>
          {view === "product"
            ? productList.map((p) => (
                <li key={p.index}>
                  <button type="button" className={product === p ? styles.explorerItemOn : styles.explorerItem} onClick={() => setProduct(p)}>
                    <span>{p.name}</span>
                    <span className={styles.tactics}>
                      {p.stringId} · {p.plans.length} service {p.plans.length === 1 ? "plan" : "plans"}
                    </span>
                  </button>
                </li>
              ))
            : planList.map((s) => (
                <li key={s.name}>
                  <button type="button" className={plan === s ? styles.explorerItemOn : styles.explorerItem} onClick={() => setPlan(s)}>
                    <span>{s.friendly || s.name}</span>
                    <span className={styles.tactics}>
                      {s.name} · in {s.products.length} {s.products.length === 1 ? "product" : "products"}
                    </span>
                  </button>
                </li>
              ))}
          {(view === "product" ? productList : planList).length === 0 && <li className={styles.explorerEmpty}>Nothing matches “{query}”.</li>}
        </ul>

        <div className={styles.explorerDetail}>
          {view === "product" && !product && <p className={styles.hint}>Choose a product on the left to see the service plans it includes.</p>}
          {view === "product" && product && (
            <>
              <h3>{product.name}</h3>
              <p className={styles.hint}>
                String ID <code>{product.stringId}</code> · GUID <code>{product.guid}</code>
              </p>
              <p className={styles.hint}>A test cannot require a product. Add the service plan inside it that the feature depends on.</p>
              <ul className={styles.tree}>
                {product.plans.map((s) => (
                  <li key={s.name}>
                    <span className={styles.treeText}>
                      <span>{planLabel(s)}</span>
                      <button type="button" className={styles.linkButton} onClick={() => showPlan(s)}>
                        in {s.products.length} {s.products.length === 1 ? "product" : "products"}
                      </button>
                    </span>
                    {pick(s)}
                  </li>
                ))}
              </ul>
            </>
          )}
          {view === "plan" && !plan && <p className={styles.hint}>Choose a service plan on the left to see the products that include it.</p>}
          {view === "plan" && plan && (
            <>
              <div className={styles.explorerPlanHead}>
                <h3>{planLabel(plan)}</h3>
                {pick(plan)}
              </div>
              <p className={styles.hint}>
                {plan.guids.length === 1 ? "GUID" : "GUIDs"} {plan.guids.map((g) => <code key={g}>{g} </code>)}
              </p>
              <p className={styles.hint}>
                Included in {plan.products.length} {plan.products.length === 1 ? "product" : "products"}. A tenant with any of them has this service plan.
              </p>
              <ul className={styles.tree}>
                {plan.products.map((p) => (
                  <li key={p.index}>
                    <span className={styles.treeText}>
                      <span>{p.name}</span>
                      <span className={styles.tactics}>{p.stringId}</span>
                    </span>
                    <button type="button" className={styles.linkButton} onClick={() => showProduct(p)}>
                      See its service plans
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      </div>
    </Dialog>
  );
}
