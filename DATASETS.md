# DATASETS.md — Receipt AI MVP

> Policy vincolante (da PROJECT.md): **vietato** usare scontrini/fatture personali reali per training/eval.
> Solo: (1) dataset pubblici con licenza compatibile, (2) dati sintetici/compositi derivati da fonti reali, (3) dizionari merchant/prodotti pubblici.
> Questo file è il registro unico delle fonti. Se una fonte non è qui, non si usa.
> Eccezione (ADR-0011): foto reali dell'utente in una cartella `debug/` locale e **gitignored**, usate solo per diagnosi/eval locale, mai training. Cfr. `docs/debug-corpus.md`.

## 1. Decisione sintetica (cosa usiamo per cosa)

| Layer | Scopo | Fonti | Uso in train |
|-------|-------|-------|--------------|
| A — OCR / parsing robustezza | testare OCR e parser su layout reali, NON per categorie | SROIE, CORD, WildReceipt | No (solo eval parser, mai come label categoria) |
| B — lessico italiano reale | nomi prodotti/merchant italiani veri per classification | Open Food Facts IT, Open Products/Beauty Facts, OpenStreetMap, volantini pubblici, esempi fattura elettronica AdE | Sì (dizionari + slot-filling) |
| C — compositore IT | template scontrino italiano + slot reali + rumore OCR | generato in-repo da Layer B | Sì (train/val principale) |
| D — golden set manuale | 150–300 esempi trascritti a mano da volantini/doc pubblici | creato in-repo, mai da dati privati | No (solo test `unknown-merchant`) |

Obiettivo: **~70% testo real-derived / ~30% augmentation, 0% random puro.**

## 2. Registro fonti

### 2.1 SROIE — Scanned Receipts OCR and Information Extraction (ICDAR 2019)
- **Contenuto:** ~1000 scan scontrini + annotazioni OCR / extraction (company, date, address, total).
- **Lingua:** inglese.
- **Licenza:** competition / research use — **non ha una licenza open chiara tipo MIT/CC**. Da verificare sul sito ufficiale ICDAR prima del download.
- **Provenienza:** ICDAR 2019 Competition on Scanned Receipt OCR and Information Extraction.
- **Uso consentito qui:** solo eval robustezza OCR/parser. **Vietato** usarlo come label di categoria (non ha la nostra taxonomy).
- **Limitazioni:** inglese, scan pulite, piccolo, layout non italiani, nessuna categoria spesa.

### 2.2 CORD — Consolidated Receipt Dataset for Post-OCR Parsing
- **Contenuto:** ~1000 scontrini indonesiani con box OCR + label semantiche (menu, subtotal, total).
- **Licenza:** **CC-BY-4.0** (verificata su repo `clovaai/cord`, file `LICENSE-CC-BY`).
- **Provenienza:** Park et al., NeurIPS Document Intelligence Workshop 2019. Mirror Hugging Face `CORD v1/v2`.
- **Uso consentito qui:** eval parser (es. estrazione totale/items). Mai per categorie.
- **Limitazioni:** lingua indonesiana, merchant mai visti in Italia, store_info/payment_info rimossi nella release pubblica per motivi legali. Utile solo per layout.

### 2.3 WildReceipt
- **Contenuto:** 1765 foto scontrini "in the wild" + ~50k box in 25 classi per key-information extraction.
- **Licenza:** **Apache-2.0** (port Hugging Face `Theivaprakasham/wildreceipt`; verificare che le immagini originali Sun et al. 2021 seguano la stessa licenza prima di ridistribuirle — usare solo per eval locale, non ricaricare immagini nel repo).
- **Provenienza:** Sun et al., arXiv:2103.14470.
- **Uso consentito qui:** stress test OCR su foto storte/mosse.
- **Limitazioni:** non italiano, nessuna nostra categoria.

### 2.4 Open Food Facts — Product Database (fonte primaria per `groceries`)
- **Contenuto:** 4M+ prodotti mondiali con barcode, nome, brand, categorie. Sottoinsieme Italia: decine di migliaia di prodotti.
- **Licenza:** **ODbL per il database + DbCL per i contenuti + CC BY-SA per le immagini.** Uso consentito anche commerciale, con **attribuzione + share-alike** dei miglioramenti al DB.
- **Provenienza:** `world.openfoodfacts.org/data` — dump `food.parquet` su Hugging Face `openfoodfacts/product-database`, CSV `en.openfoodfacts.org.products.csv.gz`.
- **Uso consentito qui:** dizionario prodotti italiani reali per slot-filling + feature item-level. Filtro `countries_tags CONTAINS 'en:italy'`.
- **Limitazioni:** nomi da etichetta (puliti), non abbreviazioni da scontrino (`BARILLA SPAGHETTI 500G` vs `BRL.SPAG.500`). Serve dizionario abbreviazioni custom. Qualità crowd-sourced disomogenea.
- **Attribuzione richiesta:** citare Open Food Facts + link licenza in README e docs.

### 2.5 Open Products Facts / Open Beauty Facts (fonti per `health`, `shopping`)
- **Contenuto:** prodotti non-food + cosmetici (pochi migliaia di record, molto più piccolo di OFF).
- **Licenza:** **stessa famiglia ODbL / share-alike** di OFF.
- **Uso consentito qui:** seed dizionario per `health` (dentifricio, shampoo) e `shopping/casa`. Non basta da solo — integrare con merchant gazetteer.
- **Limitazioni:** copertura Italia rada, serve fallback su merchant-type.

### 2.6 OpenStreetMap — Merchant Gazetteer italiano (fonte primaria per merchant)
- **Contenuto:** POI con `name + shop=* / amenity=* / brand` (es. Conad, Esselunga, Coop, Eni, Farmacia).
- **Licenza:** **ODbL, attribuzione `© OpenStreetMap contributors` obbligatoria.**
- **Uso consentito qui:** lista merchant italiani reali + `merchant_type` (supermarket, fuel, pharmacy, restaurant...). Mai inventare merchant a mano se esiste su OSM.
- **Limitazioni:** niente scontrini, solo nomi. Nomi con varianti locali (`Conad Superstore - Via Roma`). Serve normalizzazione.

### 2.7 Volantini supermercati pubblici + esempi fattura elettronica AdE
- **Contenuto:** PDF volantini (Conad, Esselunga, Coop) + template fatture di esempio pubblicati dall'Agenzia delle Entrate / produttori gestionali.
- **Licenza:** da verificare caso per caso. **Solo documenti esplicitamente pubblici/pubblicitari o esempi ufficiali. Mai PDF pescati a caso da Google Images.** Ogni file in `samples/` deve avere `source_url + data accesso + licenza presunta` in un `SOURCES.csv`.
- **Uso consentito qui:** template layout italiano reale (`TOTALE, SUBTOTALE, IVA 22%, SCONTO, N. SCONTRINO`) + prezzi plausibili.
- **Limitazioni:** volantino ≠ scontrino (manca rumore stampa). Usare solo come template, poi degradare con rumore OCR.

### 2.8 Dataset transazioni bancarie EN (ausiliari, NON primari)
- **Esempi:** Kaggle `Personal Finance Data MIT`, Hugging Face `Expense-Classifier Apache-2.0` — tutti sintetici o EN.
- **Licenza:** variabile (MIT / Apache-2.0 dove dichiarato — verificare per singolo file).
- **Uso consentito qui:** solo per mappatura taxonomy EN→IT e sanity check, mai come train principale (lingua e merchant sbagliati = domain shift).

### 2.9 Fonti ESCLUSE
- Nexdata / Shaip / vendor a pagamento, dataset senza licenza dichiarata, foto scontrini da social/forum, dati privati utente. Se non ha licenza verificabile, non si scarica.

## 3. Cosa usiamo per training / eval (taxonomy v2)

Taxonomy v2: `groceries, restaurants, transport, health, shopping, technology, leisure_travel, services, other`.

| Categoria | Segnale reale primario | Copertura stimata | Gap da colmare col compositore |
|-----------|------------------------|-------------------|--------------------------------|
| groceries | OFF Italia + OSM supermarket | alta | abbreviazioni scontrino (`PST.BRL.500G`) |
| restaurants | OSM restaurant/bar + golden set | media | nomi piatti italiani, formati ricevute |
| transport | OSM fuel/station + esempi fatture | media | Eni/IP/Q8, pedaggi, Trenitalia |
| health | Beauty Facts + OSM pharmacy | media-bassa | nomi farmaci reali solo da bugiardini pubblici |
| shopping | OSM clothes/home + Products Facts | media | Amazon generico (test ambiguità) |
| technology | OSM electronics + volantini MediaWorld-like | bassa | listini pubblici, nomi modello |
| leisure_travel | OSM hotel/cinema/museum | bassa | biglietti, booking (template) |
| services | esempi AdE + OSM services | media | bollette POD/IVA (template, mai dati reali) |
| other | — | — | solo fallback, mai trainato attivamente |

## 4. Strategia filtraggio Italia (riproducibile)

Regole:
1. Mai committare dump interi nel repo. Solo script + liste derivate versionate in `ml/data/` + `SOURCES.csv`.
2. Pin delle versioni: data download + commit/parquet version + righe filtrate.
3. Tutto il filtraggio gira locale con un comando documentato.

### 4.1 Open Food Facts → prodotti italiani

Sorgente consigliata (leggera): Parquet Hugging Face, colonne `product_name, brands, categories_tags, countries_tags, lang`.

```bash
pip install duckdb pandas pyarrow huggingface_hub
# download (pinnare la revisione nel README del dataset generato)
hf download openfoodfacts/product-database --repo-type dataset --include "food.parquet" --local-dir ./_raw_off
```

```python
import duckdb
con = duckdb.connect()
con.execute("""
COPY (
  SELECT product_name, brands, categories_tags
  FROM read_parquet('_raw_off/food.parquet')
  WHERE product_name IS NOT NULL
    AND len(product_name) BETWEEN 3 AND 120
    AND list_contains(countries_tags, 'en:italy')
) TO 'ml/data/off_italy_products.parquet' (FORMAT PARQUET);
""")
# atteso: decine di migliaia di righe; loggare SELECT count(*) in SOURCES.csv
```

Post-processing obbligatorio in-repo:
- uppercase + deaccent strip per simulare stampante scontrino;
- dizionario abbreviazioni `PASTA -> PST., BARILLA -> BRL., GRAMMI -> G` con seed manuale revisionato;
- dedup per `(normalized_name, brand)`.

### 4.2 OpenStreetMap → merchant italiani

Via Overpass (piccole extract regionali) oppure planet extract Italia filtrata con `osmium`. Esempio minimale Overpass QL (Esselunga in Lombardia — paginare per regione):

```
[out:json][timeout:60];
area["name"="Lombardia"]->.a;
(node["brand"="Esselunga"](area.a);way["brand"="Esselunga"](area.a););
out center 200;
```

Script in-repo `ml/datasets/build_merchant_gazetteer.py` (pseudocontratto):
- input: risposte Overpass / PBF Italia;
- output: `ml/data/merchant_gazetteer.csv` con `raw_name, normalized_name, merchant_type, source=osm, osm_id`;
- mapping `shop=supermarket→supermarket, amenity=fuel→fuel, amenity=pharmacy→pharmacy, amenity=restaurant→restaurant, shop=clothes→clothes...`;
- normalizzazione: lowercase, rimozione `s.r.l./s.p.a./via ...`, dedup;
- log in `SOURCES.csv`: query, data, bounding box, count.

Attribuzione obbligatoria in app/docs: `© OpenStreetMap contributors (ODbL)`.

### 4.3 Compositore (sintetico minimo, slot reali)

`ml/synthetic/compose_receipt.py` deve:
- pescare merchant dal gazetteer OSM + prodotti da OFF-IT (mai stringhe inventate salvo connettori);
- applicare 1 template italiano reale (da volantini/AdE) con campi `merchant, date, items, subtotal, IVA, total`;
- iniettare rumore OCR realistico (`O→0, l→1, e→c`, whitespace, troncamenti) + varianti maiuscole/abbreviazioni;
- emettere record con `merchant, merchant_type, items, amount, category, ocr_text` come da PROJECT.md §24.

`ml/synthetic/render_receipt.py` (issue #18) rende ogni `ocr_text` in un PNG
simil-termico con ground truth automatico (`expected.json`) e tilt/blur opzionali.
Eval OCR/layout end-to-end: far girare ML Kit sui PNG (dump `ocr.log`) e poi
`DEBUG_CORPUS_DIR=<out> flutter test mobile/test/eval_corpus_test.dart` → `docs/OCR_EVAL.md`.

### 4.4 Golden set manuale (solo test)

- `samples/golden/` — 150–300 txt + trascrizione, da volantini/fatture-esempio pubblici, trascritti a mano;
- mai usati in train; split dedicato `unknown-merchant` (merchant del golden mai presenti nel train);
- ogni file con `source_url, license, annotator, date` in `samples/golden/SOURCES.csv`.

## 5. Split anti-leakage

- Split **per merchant**, non per riga: nessun `normalized_name` del test appare nel train.
- Stratificare per categoria v2; loggare distribuzione per split.
- Metriche: accuracy, precision/recall/F1 per categoria + confusion matrix (cfr. PROJECT.md §22). Focus su `shopping vs technology` (caso Amazon) e `leisure_travel` (categoria mergiata).

## 6. Riproducibilità

```bash
python ml/datasets/build_off_italy.py --out ml/data/off_italy_products.parquet
python ml/datasets/build_merchant_gazetteer.py --region IT --out ml/data/merchant_gazetteer.csv
python ml/synthetic/compose_receipt.py --n 10000 --seed 42 --out ml/data/synth_it_10k.jsonl
python ml/evaluation/evaluate.py --test ml/data/golden.jsonl --report docs/MODEL.md
```

Ogni output deve scrivere in testa: `source, version/date, license, rows, filter`.

## 7. Rischi residui

1. Niente scontrini italiani reali classificati pubblici → il gap `volantino vs foto reale` resta. Mitigato da golden set + rumore OCR, non eliminato.
2. ODbL share-alike (OFF/OSM): se ridistribuisci DB derivati devi attribuire e condividere allo stesso modo. Ok per progetto open, da gestire se mai diventa closed.
3. SROIE senza licenza open chiara: tenerlo fuori dal repo, solo eval locale.
4. `technology` e `leisure_travel` avranno meno seed reali → F1 più basso atteso in baseline. È normale per MVP, documentarlo in `MODEL.md` invece di gonfiare il sintetico.
