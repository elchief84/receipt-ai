# Layout parsing dalla geometria, non dal testo piatto

L'OCR appiattito perde la struttura a due colonne e l'ordine fisico delle
righe. Decisione: `ReceiptLayoutParser` lavora sui bounding box ML Kit —
righe visive in ordine canonico (top→bottom, left→right) con stima della
tilt (mediana robusta su coppie cross-colonna, cap 8.5°), poi tipizzazione
righe, corpo, raggruppamento, validazione con sum-check.

## Considered Options

- Euristiche sul testo piatto (pairColumns/mergeFragments/attachAdjacent)
  — rimosse: ogni scontrino nuovo rompeva la precedente, ordine fisico
  perso già in partenza (le righe venivano riordinate per indice di
  emissione ML Kit).
- Solo overlap verticale — tollera ~2° di tilt, insufficiente su foto reali.

## Consequences

Debug `[OCR-GEOM]` (riga+box) in console: i fixture futuri includono la
geometria reale, così i test girano sullo stesso percorso del device.
Senza box (sample/test) il parser degrada a righe = linee di testo.
