# OCR in MVP con Tesseract locale

Status: superseded by ADR-0004

MVP include OCR fotografico end-to-end (Flutter foto → API → Tesseract `ita+eng` → classify), non solo testo pulito. Eval ufficiale resta su testo per isolare errori OCR da errori di classificazione, ma la pipeline foto deve funzionare via `./start.sh`.

## Consequences

Backend espone sia `POST /classify {text}` (test modello) sia path immagine → OCR → classify; serve preprocessing minimo e gestione fallimenti OCR a bassa qualità.
