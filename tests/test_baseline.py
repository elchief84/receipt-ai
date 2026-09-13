from ml.evaluation.baseline_lookup import LookupClassifier, evaluate


def _rec(merchant, category, text=""):
    return {
        "merchant": {
            "raw_name": merchant,
            "normalized_name": merchant,
            "merchant_type": "supermarket",
        },
        "category": category,
        "ocr_text": text or merchant,
    }


def test_lookup_predicts_known_merchant():
    clf = LookupClassifier().fit([_rec("conad", "groceries")])
    assert clf.predict(_rec("conad", "groceries")) == "groceries"


def test_lookup_falls_back_on_unknown_merchant():
    clf = LookupClassifier().fit(
        [_rec("conad", "groceries"), _rec("conad", "groceries"), _rec("eni", "transport")]
    )
    assert clf.predict(_rec("mai-visto", "groceries")) == "groceries"  # majority fallback


def test_evaluate_reports_accuracy_f1_and_confusion():
    train = [_rec("conad", "groceries")] * 4 + [_rec("eni", "transport")] * 4
    test = [_rec("conad", "groceries")] * 2 + [_rec("eni", "transport")] * 2
    report = evaluate(LookupClassifier().fit(train), test)
    assert report["accuracy"] == 1.0
    assert report["f1_macro"] == 1.0
    assert set(report["per_category"]) == {"groceries", "transport"}
    assert len(report["confusion_matrix"]) == 2
