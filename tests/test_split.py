from ml.evaluation.split import per_merchant_split


def _rec(merchant, category):
    return {
        "merchant": {
            "raw_name": merchant,
            "normalized_name": merchant,
            "merchant_type": "supermarket",
        },
        "category": category,
    }


def test_split_has_no_merchant_overlap():
    records = [_rec("conad", "groceries")] * 10 + [_rec("esselunga", "groceries")] * 10
    train, test = per_merchant_split(records, test_ratio=0.5, seed=1)
    train_m = {r["merchant"]["normalized_name"] for r in train}
    test_m = {r["merchant"]["normalized_name"] for r in test}
    assert train_m.isdisjoint(test_m)
    assert len(train) + len(test) == len(records)


def test_split_keeps_all_records_and_both_sides_nonempty():
    records = (
        [_rec("conad", "groceries")] * 6
        + [_rec("esselunga", "groceries")] * 6
        + [_rec("eni", "transport")] * 6
    )
    train, test = per_merchant_split(records, test_ratio=0.34, seed=42)
    assert train and test
    assert len(train) + len(test) == len(records)
