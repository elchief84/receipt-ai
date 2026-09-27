# Corpus di debug locale

Cartella `debug/`, **gitignored**, per diagnosticare i fallimenti OCR/layout
su foto reali. Regole (ADR-0011): solo diagnosi ed eval locale, mai training,
mai commit, mai upload.

## Cattura di un campione

1. Da app, premi **Take photo** / **Choose image** su uno scontrino RT che
   fallisce.
2. Il flusso stampa in console due blocchi:
   - `[OCR-TEXT-START] … [OCR-TEXT-END]` — testo OCR appiattito;
   - `[OCR-GEOM-START] … [OCR-GEOM-END]` — una riga per linea OCR:
     `G <left> <top> <right> <bottom> | <angle> | <confidence> | <text>`.
3. Salva i due blocchi su file:

   ```bash
   flutter run 2>&1 | tee debug/<slug>/ocr.log
   ```

   Puoi incollare l'output di `flutter run` **così com'è**: l'harness metriche
   rimuove da solo il prefisso logcat (`I/flutter (12835): …`) e le righe di
   rumore (`… identical N line`).

4. Copia anche la foto originale in `debug/<slug>/photo.jpg`.
5. Scrivi `debug/<slug>/expected.json` con la verita' attesa:

   ```json
   {
     "merchant": "CONAD",
     "total": 10.60,
     "items": [
       {"description": "LATTE INTERO 1L", "price": 1.49}
     ]
   }
   ```

6. (Opzionale) `notes.md`: sintomo osservato (righe mischiate? prezzo su
   riga sbagliata? testo illeggibile?).

## Formato della cartella

```
debug/
  <slug>/
    photo.jpg
    ocr.log          # [OCR-TEXT] + [OCR-GEOM]
    expected.json    # ground truth (totale, items)
    notes.md         # opzionale: sintomo
```

## Uso

- Diagnosi manuale: la vista di debug (issue #9) disegna i box e
  l'assegnazione riga-prezzo.
- Eval: l'harness metriche (issue #12) legge questa cartella per calcolare
  exact-match totale, item count, sum-consistency, CER, field-F1.
