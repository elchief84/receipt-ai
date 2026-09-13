"""Experiment 2: TF-IDF + Logistic Regression with merchant-only ablation.

Feature contract (must match the Dart port exactly):
  1. normalize with ml.datasets.normalize.normalize_name
  2. split on single spaces
  3. tf-idf with smooth idf, l2 norm, sublinear off
"""

import argparse
import json
import math
from collections import Counter

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score

from ml.datasets.normalize import normalize_name

TOKENIZER_SPEC = "normalize_name+split-v1"


def features_merchant_only(record: dict) -> str:
    return record["merchant"]["normalized_name"]


def features_full(record: dict) -> str:
    items = " ".join(i["raw_description"] for i in record.get("items", []))
    return " ".join(
        [
            record["merchant"]["normalized_name"],
            record["merchant"]["merchant_type"],
            record.get("ocr_text", ""),
            items,
        ]
    )


def _fit_predict(train_texts: list, train_labels: list, test_texts: list) -> dict:
    vectorizer = TfidfVectorizer(
        preprocessor=normalize_name, tokenizer=str.split, max_features=4000
    )
    clf = LogisticRegression(max_iter=1000, C=4.0)
    X_train = vectorizer.fit_transform(train_texts)
    clf.fit(X_train, train_labels)
    X_test = vectorizer.transform(test_texts)
    predictions = clf.predict(X_test).tolist()
    export = {
        "tokenizer_spec": TOKENIZER_SPEC,
        "vocabulary": {t: int(i) for t, i in vectorizer.vocabulary_.items()},
        "idf": [float(x) for x in vectorizer.idf_],
        "coef": [[float(x) for x in row] for row in clf.coef_.tolist()],
        "intercept": [float(x) for x in clf.intercept_.tolist()],
        "classes": [str(x) for x in clf.classes_.tolist()],
    }
    return {"predictions": predictions, "export": export}


def predict_with_export(export: dict, text: str) -> str:
    terms = normalize_name(text).split()
    counts = Counter(t for t in terms if t in export["vocabulary"])
    weighted = {}
    for term, count in counts.items():
        idx = export["vocabulary"][term]
        weighted[idx] = count * export["idf"][idx]
    norm = math.sqrt(sum(v * v for v in weighted.values())) or 1.0
    scores = list(export["intercept"])
    for idx, value in weighted.items():
        tfidf = value / norm
        for c in range(len(scores)):
            scores[c] += export["coef"][c][idx] * tfidf
    if len(scores) == 1:
        # binary sklearn: single row, sign decides classes[1] vs classes[0]
        return export["classes"][1] if scores[0] > 0 else export["classes"][0]
    best = max(range(len(scores)), key=lambda c: scores[c])
    return export["classes"][best]


def train_and_evaluate(train: list, test: list) -> dict:
    y_train = [r["category"] for r in train]
    y_test = [r["category"] for r in test]
    out = {}
    for name, fn in (
        ("merchant_only", features_merchant_only),
        ("full", features_full),
    ):
        res = _fit_predict(
            [fn(r) for r in train], y_train, [fn(r) for r in test]
        )
        res["accuracy"] = accuracy_score(y_test, res["predictions"])
        res["f1_macro"] = f1_score(y_test, res["predictions"], average="macro")
        out[name] = res
    out["export"] = out["full"]["export"]
    out["labels"] = sorted(set(y_train) | set(y_test))
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="src", required=True)
    parser.add_argument("--test-ratio", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    import os

    from ml.evaluation.split import per_merchant_split

    with open(args.src, encoding="utf-8") as f:
        records = [json.loads(line) for line in f if line.strip()]
    train, test = per_merchant_split(records, args.test_ratio, args.seed)
    result = train_and_evaluate(train, test)

    os.makedirs(args.out_dir, exist_ok=True)
    with open(os.path.join(args.out_dir, "classifier.json"), "w", encoding="utf-8") as f:
        json.dump(result["export"], f, ensure_ascii=False)
    report = {
        "n_train": len(train),
        "n_test": len(test),
        "train_merchants": sorted({r["merchant"]["normalized_name"] for r in train}),
        "test_merchants": sorted({r["merchant"]["normalized_name"] for r in test}),
        "merchant_only": {
            "accuracy": result["merchant_only"]["accuracy"],
            "f1_macro": result["merchant_only"]["f1_macro"],
        },
        "full": {
            "accuracy": result["full"]["accuracy"],
            "f1_macro": result["full"]["f1_macro"],
        },
        "labels": result["labels"],
    }
    with open(os.path.join(args.out_dir, "ablation_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(
        f"merchant_only acc={report['merchant_only']['accuracy']:.3f} "
        f"f1={report['merchant_only']['f1_macro']:.3f} | "
        f"full acc={report['full']['accuracy']:.3f} "
        f"f1={report['full']['f1_macro']:.3f}"
    )


if __name__ == "__main__":
    main()
