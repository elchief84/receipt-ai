# Tutto on-device, niente backend server-side

Training resta in Python offline, ma inference MVP gira interamente sul telefono: OCR + merchant normalization + classifier dentro l'app Flutter, nessun API server da avviare. Deciso su richiesta esplicita utente per privacy/offline/semplicità di demo.

## Considered Options

- API locale Python (FastAPI) + app thin client — scartata: richiede `./start.sh` con due processi, invio immagini in rete anche se localhost.
- On-device scelta: OCR via ML Kit Text Recognition (o Tesseract-mobile fallback), classifier come asset embedded (gazetteer + TF-IDF/LogReg esportato in TFLite/ONNX o porte Dart).

## Consequences

PROJECT.md §11-12 da riscrivere: niente `POST /classify` server in MVP, solo harness di test locale. Feedback salvato solo on-device (SQLite/Hive). Vincolo nuovo: modello <10MB, inference <500ms su medio gamma.
