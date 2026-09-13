"""Merchant-lookup baseline (experiment 1): majority category per merchant."""

from collections import Counter

from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_recall_fscore_support,
)


class LookupClassifier:
    def fit(self, records: list) -> "LookupClassifier":
        per_merchant: dict = {}
        for rec in records:
            key = rec["merchant"]["normalized_name"]
            per_merchant.setdefault(key, []).append(rec["category"])
        self._table = {
            name: Counter(cats).most_common(1)[0][0]
            for name, cats in per_merchant.items()
        }
        self._fallback = Counter(r["category"] for r in records).most_common(1)[0][0]
        return self

    def predict(self, record: dict) -> str:
        return self._table.get(
            record["merchant"]["normalized_name"], self._fallback
        )


def evaluate(clf: LookupClassifier, records: list) -> dict:
    y_true = [r["category"] for r in records]
    y_pred = [clf.predict(r) for r in records]
    labels = sorted(set(y_true) | set(y_pred))
    precision, recall, f1, _ = precision_recall_fscore_support(
        y_true, y_pred, labels=labels, zero_division=0
    )
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "f1_macro": f1_score(y_true, y_pred, average="macro", zero_division=0),
        "per_category": {
            label: {"precision": p, "recall": r, "f1": f}
            for label, p, r, f in zip(labels, precision, recall, f1)
        },
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
        "labels": labels,
    }
