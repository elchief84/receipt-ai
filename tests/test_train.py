from ml.evaluation.split import per_merchant_split
from ml.training.train_logreg import (
    features_full,
    features_merchant_only,
    predict_with_export,
    train_and_evaluate,
)


def _rec(merchant, category, text):
    return {
        "merchant": {
            "raw_name": merchant,
            "normalized_name": merchant,
            "merchant_type": "supermarket",
        },
        "category": category,
        "ocr_text": text,
        "items": [{"raw_description": text, "quantity": 1, "unit_price": 1.0, "total": 1.0}],
    }


def _fixture():
    return (
        [_rec("shop-a", "groceries", "latte pasta pane")] * 4
        + [_rec("tech-b", "technology", "cuffie cavo bluetooth")] * 4
        + [_rec("shop-c", "groceries", "latte pasta biscotti")] * 2
        + [_rec("tech-d", "technology", "cuffie cavo usb")] * 2
    )


def test_full_text_beats_merchant_only_on_unknown_merchants():
    train = (
        [_rec("conad", "groceries", "latte pasta pane")] * 4
        + [_rec("unieuro", "technology", "cuffie cavo bluetooth")] * 4
    )
    test = (
        [_rec("esselunga", "groceries", "latte pasta biscotti")] * 2
        + [_rec("mediaworld", "technology", "cuffie cavo usb")] * 2
    )
    result = train_and_evaluate(train, test)
    assert result["merchant_only"]["accuracy"] == 0.5
    assert result["full"]["accuracy"] == 1.0


def test_export_parity_with_sklearn():
    records = _fixture()
    train, test = per_merchant_split(records, test_ratio=0.5, seed=1)
    result = train_and_evaluate(train, test)
    for rec in test:
        assert predict_with_export(result["export"], features_full(rec)) == result[
            "full"
        ]["predictions"][test.index(rec)]


def test_features_include_items_and_type():
    rec = _rec("Amazon", "technology", "cuffie bluetooth")
    rec["merchant"]["merchant_type"] = "ecommerce"
    text = features_full(rec)
    assert "cuffie" in text and "ecommerce" in text and "Amazon" in text
    assert features_merchant_only(rec) == "Amazon"
