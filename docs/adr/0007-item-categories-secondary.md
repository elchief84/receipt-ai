# Item categories as secondary signal, transaction stays primary

Mixed baskets (Amazon order: phone + toy) prove one label per Transaction
loses information. Decision: keep expense_category at Transaction level as
primary (the Summary screen needs one total per category), and add optional
per-item Classification shown in Result. No total-splitting in Summary yet:
splitting €195,83 across categories changes summary semantics and needs
item amounts that fiscal receipts often lack.

## Considered Options

- Transaction-only (status quo): simple, wrong on mixed baskets.
- Full item-level with pro-rata totals: correct but needs reliable item
  amounts + summary redesign — premature for MVP.
- Chosen middle: item labels displayed, transaction label decides summary.
