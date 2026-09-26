# Receipt AI — MVP on-device

Classifica spese italiane da foto di scontrini, 100% on-device, solo dati pubblici e derivati.

## Demo

```bash
cd mobile && flutter run
```

Home → **Use sample receipt** (Conad, ENI, Amazon Tech/Generic, Farmacia, Ristorante)
→ Result (merchant, totale, categoria, confidence) → Correct / Change category
→ Summary (This month). Foto reali via Take photo (ML Kit on-device).

## Pipeline ML (offline)

```bash
python -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m ml.datasets.build_off_italy --in ml/data/seeds/products_seed.csv --out ml/data/off_italy_products.parquet
.venv/bin/python -m ml.datasets.build_merchant_gazetteer --in ml/data/seeds/merchants_seed.csv --out ml/data/merchant_gazetteer.csv
.venv/bin/python -m ml.synthetic.compose_receipt --merchants ml/data/seeds/merchants_seed.csv --products ml/data/seeds/products_seed.csv --n 10000 --seed 42 --out /tmp/synth.jsonl
.venv/bin/python -m ml.training.train_logreg --in /tmp/synth.jsonl --seed 42 --out-dir ml/data/exp2
# Immagini sintetiche + ground truth per eval OCR/layout (issue #18): vedi docs/debug-corpus.md
.venv/bin/python -m ml.synthetic.render_receipt --in /tmp/synth.jsonl --out /tmp/receipt_images --n 200 --seed 42
.venv/bin/python -m pytest tests -q
```

Risultati in `MODEL.md`: lookup 0.000 / LogReg full 0.490 accuracy su merchant mai visti.

## Docs

`PROJECT.md`, `ARCHITECTURE.md`, `DATASETS.md`, `MODEL.md`, `CONTEXT.md`, `docs/adr/`.
Spec e ticket: GitHub issues #1–#5 (chiusi).

## Attribuzioni (obbligatorie, ODbL)

- Merchant/product seeds: nomi di pubblico dominio; run completi usano
  Open Food Facts (ODbL/DbCL) e OpenStreetMap © OpenStreetMap contributors (ODbL).
- Robustezza parser: SROIE, CORD (CC-BY-4.0), WildReceipt (Apache-2.0) — solo eval locale.
- Dettagli e licenze in `DATASETS.md` e `ml/data/SOURCES.csv`.
