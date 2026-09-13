# ARCHITECTURE.md — Receipt AI MVP on-device

> Supersede: PROJECT.md §11–12 (niente API server in MVP). Training in Python offline, inference 100% on-device. Cfr. ADR-0001, 0003, 0004, 0005.
> Scope: solo scontrini fiscali RT italiani; resto rifiutato con errore esplicito (ADR-0008).

## 1. Pipeline

```
Foto / Sample
  ↓
ML Kit Text Recognition v2 on-device  (ita+eng, offline)
  ↓ OCR text
Transaction Extraction (Dart: regex date/total/IVA)
  ↓ Transaction bozza
Merchant Normalization (gazetteer OSM embedded + regole)
  ↓ merchant.normalized_name + merchant_type (lista chiusa)
Expense Classifier (TFLite TF-IDF/LogReg quantizzato + fallback keyword)
  ↓ Classification {category, confidence, model_version}
UI: Result + Feedback locale
```

Ogni stage è un'interfaccia Dart sostituibile. Nessuna chiamata rete.

## 2. Componenti mobile (`/mobile`)

- `features/capture`: Take photo / Choose image / Use sample receipt. OCR via ML Kit, mostra `text_raw` se confidence OCR bassa.
- `core/ocr`: wrapper `OcrEngine` (impl MVP = ML Kit, interfaccia pronta per Tesseract-mobile).
- `core/parsing`: `TransactionExtractor` — regex IT (`TOTALE`, `SUBTOTALE`, `IVA 22%`, date `dd/mm/yyyy`, importi `€1.234,56` → normalizzati).
- `core/merchant`: `MerchantNormalizer` + `assets/merchant_gazetteer.csv` (da OSM, cfr. DATASETS.md) + lista chiusa merchant_type:
  `supermarket, fuel, pharmacy, restaurant, clothes, home_store, electronics, hotel, transport_service, services, ecommerce, other`.
- `core/classify`: `Classifier` → JSON logistico embedded (`assets/classifier.json`, cfr. ADR-0006) + fallback keyword scoring. Interfaccia stabile:
  `classify({merchant, merchant_type, ocr_text, items}) → {category, confidence, model_version}`.
- `features/result`: merchant, date, total, category, confidence% + [Correct] [Change category].
- `features/summary`: This month per categoria, chart semplice.
- `core/feedback`: store locale (SQLite/Hive) `{original, corrected, transaction, model_version, timestamp}`. Mai upload, mai retrain online.
- `assets/samples/`: 6+ scontrini sintetici (Conad, Eni, Amazon-tech, Amazon-generic, Farmacia, Ristorante) per demo senza foto.

Vincoli: modello <10MB, inference <500ms su medio gamma, offline dal primo avvio.

## 3. Componenti ML offline (`/ml`, solo desktop)

- `ml/datasets/`: script filtraggio OFF-IT + gazetteer OSM (cfr. DATASETS.md). Mai committare dump interi.
- `ml/synthetic/`: compositore template IT reali + slot reali + rumore OCR. Output `synth_it_10k.jsonl`.
- `ml/training/`: exp1 merchant-lookup → exp2 TF-IDF+LogReg → exp3 export TFLite quantizzato. Harness di test Dart-equivalente per parità.
- `ml/evaluation/`: split **per merchant** (nessun normalized_name in comune train/test) + merchant perturbati auto (`Conad→Conadd`) per unknown-merchant senza lavoro manuale (ADR-0003). Metriche: **F1-macro** primaria + accuracy, precision/recall per categoria, confusion matrix con focus `shopping vs technology`.

## 4. Taxonomy e regole (da CONTEXT.md + ADR-0001)

Taxonomy v2: `groceries, restaurants, transport, health, shopping, technology, leisure_travel, services, other`.
Regola rigida: per `shopping / technology / leisure_travel` il merchant da solo non basta — obbligatorio ablation `merchant-only vs merchant+text+items` in eval.

## 5. Repository

```
/ml/{datasets,synthetic,training,evaluation}  # python offline, niente server
/mobile/{lib/{core,features},assets/{classifier.json,merchant_gazetteer.csv},test}
  # flutter, tutto on-device
/samples/          # esempi pubblici con SOURCES.csv
/docs/adr/         # decisioni (0001–0005)
CONTEXT.md DATASETS.md ARCHITECTURE.md MODEL.md README.md
```

Niente `/backend`. `start.sh` futuro = `flutter run` soltanto.

## 6. Testing MVP

- Dart: extractor + normalizer + classifier-wrapper unit test, widget test Home/Result/Summary.
- Python: dataset validation, preprocessing, classifier parity test (stesso input → stessa categoria Dart vs Python ± tolleranza quantizzazione).
- Pochi test significativi, niente coverage artificiale.

## 7. Rischi

1. Parità Python↔TFLite↔Dart (tokenizer TF-IDF deve essere identico — fissare lowercase/strip/deaccent in un unico spec).
2. ML Kit vs Tesseract-desktop: WER diverso, eval su testo isola il problema ma demo foto può deludere.
3. `technology / leisure_travel` con pochi seed reali → F1 basso atteso, da documentare in MODEL.md senza gonfiare sintetico.
4. ODbL share-alike OFF/OSM: attribuzione obbligatoria in app + README.
