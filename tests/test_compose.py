import csv
import json

import pyarrow.parquet as pq

from ml.synthetic.compose_receipt import (
    add_ocr_noise,
    compose_record,
    load_seeds,
    render_text,
)


def test_compose_record_schema_and_totals(tmp_path):
    seeds = load_seeds(
        str(tmp_path / "m.csv"), str(tmp_path / "p.csv"), fixture=True
    )
    import random

    rng = random.Random(7)
    rec = compose_record(rng, seeds)
    assert set(rec) == {
        "merchant",
        "date",
        "items",
        "amount",
        "category",
        "ocr_text",
    }
    assert set(rec["merchant"]) == {"raw_name", "normalized_name", "merchant_type"}
    assert set(rec["amount"]) == {"total", "currency"}
    assert rec["amount"]["currency"] == "EUR"
    assert rec["items"], "at least one item"
    expected = round(sum(i["total"] for i in rec["items"]), 2)
    assert rec["amount"]["total"] == expected
    assert rec["merchant"]["raw_name"] in rec["ocr_text"]


def test_compose_is_deterministic_for_same_seed(tmp_path):
    import random

    seeds = load_seeds(
        str(tmp_path / "m.csv"), str(tmp_path / "p.csv"), fixture=True
    )
    rec1 = compose_record(random.Random(42), seeds)
    rec2 = compose_record(random.Random(42), seeds)
    assert rec1 == rec2


def test_ecommerce_category_comes_from_items_not_merchant(tmp_path):
    import random

    seeds = load_seeds(
        str(tmp_path / "m.csv"), str(tmp_path / "p.csv"), fixture=True
    )
    tech = compose_record(
        random.Random(1), seeds, force_merchant="amazon", force_category="technology"
    )
    generic = compose_record(
        random.Random(1), seeds, force_merchant="amazon", force_category="shopping"
    )
    assert tech["merchant"]["normalized_name"] == generic["merchant"]["normalized_name"]
    assert tech["category"] == "technology"
    assert generic["category"] == "shopping"
    assert tech["items"] != generic["items"]


def test_ocr_noise_applies_but_keeps_digits_of_total():
    import random

    clean = "CONAD SUPERSTORE\nTOTALE 10.60"
    noisy = add_ocr_noise(clean, random.Random(3), error_rate=0.3)
    assert "10.60" in noisy  # digits must survive
    assert noisy != clean  # some letter-level noise applied
