# Merchant type non implica expense category

Per le categorie ambigue (`shopping`, `technology`, `leisure_travel`) il merchant da solo non basta mai: la classificazione deve usare OCR text e/o items. Deciso per evitare che il modello memorizzi `CONAD = groceries` senza generalizzare.

## Considered Options

- Lookup merchant → category (semplice ma non generalizza su Amazon/Decathlon/IKEA).
- Regola rigida scelta: ablation obbligatoria `merchant-only vs merchant+text+items` in evaluation.
