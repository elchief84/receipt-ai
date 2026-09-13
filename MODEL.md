# MODEL.md — Receipt AI MVP

## Esperimenti

Tutti con split **per merchant** (nessun `normalized_name` in comune train/test) su
`synth_it_10k.jsonl` (seed 42, 7869 train / 2131 test).
Test merchants: decathlon, feltrinelli, nh hotel, ovs — mai visti nel train.

### Exp1 — merchant lookup (baseline)

Majority category per merchant normalizzato, fallback maggioranza globale.

| metrica | valore |
|---------|--------|
| accuracy | 0.000 |
| F1-macro | 0.000 |

Il lookup memorizza e non generalizza: su merchant mai visti sbaglia tutto.
Report: `ml/data/baseline_lookup_report.json`.

### Exp2 — TF-IDF + Logistic Regression

`TfidfVectorizer(preprocessor=normalize_name, tokenizer=split, max_features=4000)`
+ `LogisticRegression(C=4, max_iter=1000)`. Seed a 47 prodotti (tech: Smartphone/Cover; toys: Tavolino/Gioco).
Ablation sullo stesso split:

| features | accuracy | F1-macro |
|----------|----------|----------|
| merchant_only | 0.000 | 0.000 |
| full (merchant + type + OCR text + items) | 0.490 | 0.200 |

Il segnale testuale/items porta da 0% a 49% su merchant mai visti: la regola
rigida ADR-0001 è confermata dai numeri, non solo dal principio.
Report: `ml/data/exp2/ablation_report.json`.
F1-macro resta bassa: 4 soli merchant nel test, categorie povere
(`technology`, `leisure_travel`) quasi assenti — atteso con seed da 20 prodotti,
da documentare non da gonfiare con sintetico casuale.

## Holdout unknown-merchant (ADR-0003, niente golden manuale)

Test merchants con nomi perturbati automaticamente (`Conad→Conadd`,
typo OCR, slip vocalici: `ml/evaluation/perturb.py`), mai visti nel train:

| features | accuracy | F1-macro |
|----------|----------|----------|
| merchant_only | 0.000 | 0.000 |
| full | 0.490 | 0.200 |

Il modello full non degrada coi typo perché generalizza via items/testo,
non via nome merchant. Report: `ml/data/exp2/holdout_report.json`.

## Modello embedded

`ml/data/exp2/classifier.json` (vocabolario 394 termini + idf + coef) con
`tokenizer_spec: normalize_name+split-v1`. Inference replicata in Dart puro
(parità testata in `tests/test_train.py`). Cfr. ADR-0006 (JSON, non TFLite).
Spot-check: testo farmacia reale-like → health 99.5% (prima 53%);
ordine Amazon misto (phone+cover+toy) → technology 63%.

## Confronto

| | accuracy (unknown) | F1-macro | size | inference | complessità |
|---|---|---|---|---|---|
| lookup | 0.000 | 0.000 | ~KB | istantanea | minima |
| TF-IDF+LogReg | 0.490 | 0.200 | 48KB | <50ms | bassa |

Scelto LogReg per MVP: unico che generalizza oltre il merchant, costo nullo.

## Limiti noti

- Copertura seed minima (20 prodotti): `technology`/`leisure_travel` deboli.
- Rumore OCR solo lettere; WER foto reali ML Kit da misurare in T4.
- Multinomiale su 7 classi viste; `other` quasi mai predetta.
