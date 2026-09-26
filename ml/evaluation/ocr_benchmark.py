"""OCR engine benchmark over a rendered synthetic set (issue #20).

Pluggable engines, same metric, same dataset — the harness the "ML Kit vs
alternative" decision needs. Two engines ship here:

  tesseract   desktop proxy via pytesseract (needs the tesseract binary;
              `pip install pytesseract`; Italian needs `tesseract-lang`)
  mlkit       reads the on-device `[OCR-TEXT]` dump (`<id>/ocr.log`) the
              app already writes, so ML Kit numbers plug in unchanged.

Metrics vs the rendered ground truth (`<id>/meta.json: ocr_text`):
  CER  character error rate (Levenshtein / chars)
  WER  word error rate (Levenshtein over normalized tokens)

Usage:
  python -m ml.evaluation.ocr_benchmark --dataset /tmp/receipt_images \\
      --engine tesseract --lang eng --out /tmp/ocr_bench.json
"""

import argparse
import json
import os
import re


def _norm_tokens(s: str) -> list[str]:
    return re.sub(r"[^a-z0-9 ]", " ", s.lower()).split()


def _lev(a, b) -> int:
    prev = list(range(len(b) + 1))
    cur = [0] * (len(b) + 1)
    for i in range(1, len(a) + 1):
        cur[0] = i
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        prev, cur = cur, prev
    return prev[len(b)]


def cer(hyp: str, ref: str) -> float:
    if not ref:
        return 0.0
    return _lev(hyp, ref) / len(ref)


def wer(hyp: str, ref: str) -> float:
    h, r = _norm_tokens(hyp), _norm_tokens(ref)
    if not r:
        return 0.0
    return _lev(h, r) / len(r)


def _engine_tesseract(sample_dir: str, lang: str) -> str | None:
    import pytesseract
    from PIL import Image

    png = os.path.join(sample_dir, "receipt.png")
    if not os.path.exists(png):
        return None
    return pytesseract.image_to_string(Image.open(png), lang=lang)


_TEXT_START = "[OCR-TEXT-START]"
_TEXT_END = "[OCR-TEXT-END]"


def _engine_mlkit(sample_dir: str, _lang: str) -> str | None:
    log = os.path.join(sample_dir, "ocr.log")
    if not os.path.exists(log):
        return None
    text = open(log, encoding="utf-8").read()
    s, e = text.find(_TEXT_START), text.find(_TEXT_END)
    if s < 0 or e < 0:
        return None
    return text[s + len(_TEXT_START) : e].strip()


ENGINES = {"tesseract": _engine_tesseract, "mlkit": _engine_mlkit}


def run(dataset: str, engine: str, lang: str) -> dict:
    fn = ENGINES[engine]
    rows = []
    for sid in sorted(os.listdir(dataset)):
        sdir = os.path.join(dataset, sid)
        meta = os.path.join(sdir, "meta.json")
        if not os.path.isdir(sdir) or not os.path.exists(meta):
            continue
        ref = json.load(open(meta, encoding="utf-8")).get("ocr_text", "")
        hyp = fn(sdir, lang)
        if hyp is None:
            continue
        rows.append({"id": sid, "cer": cer(hyp, ref), "wer": wer(hyp, ref)})
    if not rows:
        return {"engine": engine, "samples": 0, "cer": None, "wer": None, "rows": []}
    return {
        "engine": engine,
        "lang": lang,
        "samples": len(rows),
        "cer": sum(r["cer"] for r in rows) / len(rows),
        "wer": sum(r["wer"] for r in rows) / len(rows),
        "rows": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--engine", choices=list(ENGINES), required=True)
    parser.add_argument("--lang", default="eng")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    report = run(args.dataset, args.engine, args.lang)
    print(
        f"{report['engine']}: n={report['samples']} "
        f"CER={report['cer']} WER={report['wer']}"
    )
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
