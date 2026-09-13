# Scope: only Italian RT fiscal receipts, explicit reject otherwise

Chasing arbitrary document classes (web order summaries, pre-euro
receipts, foreign layouts) made coverage unmeasurable: every new class
was a new exception factory. Decision: the app supports ONLY Italian
fiscal receipts from Registratori Telematici. `isFiscalReceipt` gates
every input (photo or sample); anything else gets an explicit
"documento non supportato" error, never garbage output.

## Considered Options

- Unbounded documents with best-effort parsing — rejected: endless
  exceptions, no definable 95%.
- LLM extraction for the long tail — rejected for now: cost, latency,
  offline and privacy breakage (see discussion, Sep 2026).
- Chosen: RT-only scope. RT layout is mandated by law (DOCUMENTO
  COMMERCIALE, matricola RT, TOTALE COMPLESSIVO), so variants are
  finite and 95% coverage is measurable on the regression corpus.
