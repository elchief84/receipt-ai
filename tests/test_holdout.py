import random

from ml.datasets.normalize import normalize_name
from ml.evaluation.perturb import perturb_merchant, perturb_record
from ml.evaluation.split import per_merchant_split
from ml.training.train_logreg import train_and_evaluate


def _rec(merchant, category, text):
    return {
        "merchant": {
            "raw_name": merchant,
            "normalized_name": normalize_name(merchant),
            "merchant_type": "supermarket",
        },
        "category": category,
        "ocr_text": text,
        "items": [],
    }


def test_perturbed_names_differ_after_normalize():
    rng = random.Random(0)
    seen = {normalize_name(perturb_merchant("Conad Superstore", rng)) for _ in range(20)}
    assert "conad superstore" not in seen


def test_holdout_report_structure_and_disjoint_merchants():
    train = [_rec("Conad", "groceries", "latte pane")] * 4 + [
        _rec("Eni", "transport", "benzina")
    ] * 4
    rng = random.Random(5)
    perturbed = [perturb_record(_rec("Esselunga", "groceries", "latte pane"), rng)]
    train_names = {r["merchant"]["normalized_name"] for r in train}
    test_names = {r["merchant"]["normalized_name"] for r in perturbed}
    assert train_names.isdisjoint(test_names)
    result = train_and_evaluate(train, perturbed)
    assert set(result) >= {"merchant_only", "full", "labels"}
    assert "accuracy" in result["full"]
