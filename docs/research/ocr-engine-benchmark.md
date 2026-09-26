# OCR engine benchmark (issue #20)

Harness: `ml/evaluation/ocr_benchmark.py` — pluggable engines, one metric, one
dataset. Engines ship-ready:

- `tesseract` — desktop proxy (`pytesseract`; needs the `tesseract` binary).
- `mlkit` — reads the on-device `[OCR-TEXT]` dump the app already writes, so
  ML Kit slots in with no new code.

Metric: CER (char error rate) e WER (word error rate) vs il ground truth
`ocr_text` dei campioni renderizzati (#18).

## Baseline misurata (desktop, proxy)

Dataset: 30 scontrini sintetici renderizzati (`/tmp/ocr_bench`, seed 7, no
tilt/blur), Tesseract `--lang eng` (italiano non installato sul sistema).

| engine | n | CER | WER |
|--------|:-:|:---:|:---:|
| tesseract (eng) | 30 | 27.7% | 21.0% |
| ML Kit | — | — | — |

Tesseract senza `ita` è un estremo inferiore, non un candidato reale: serve
solo a validare l'harness e fissare un riferimento.

## Come misurare ML Kit (device)

1. Genera il set: `python -m ml.synthetic.render_receipt --in <synth.jsonl> --out <dir> --n 300`.
2. Sul telefono, apri ogni PNG (debug overlay / flusso foto) e salva il dump
   come `<dir>/<id>/ocr.log` (`[OCR-TEXT]`/`[OCR-GEOM]`).
3. `python -m ml.evaluation.ocr_benchmark --dataset <dir> --engine mlkit`.
4. Se ML Kit resta sopra la soglia di adozione, prova un engine alternativo
   (PaddleOCR-mobile / Apple Vision) dietro il seam `OcrEngine` e ripeti.

## Criteri di decisione

- Soglia di adozione: ML Kit è sufficiente se CER sul set **pulito** ≤ 5% e
  sul set **tilt/blur** ≤ 12%; altrimenti si valuta un engine alternativo.
- Un engine alternativo si adotta solo se batte ML Kit di ≥ 5 punti di CER a
  fronte di un bundle e di una latenza accettabili (< 10 MB, < 500 ms).

## Stato

Decisione **non ancora presa**: mancano i numeri ML Kit (device). L'harness e
la baseline Tesseract sono pronti; il passo 2 richiede un dispositivo.
