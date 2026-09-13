import csv

import pyarrow.parquet as pq

from ml.datasets.build_merchant_gazetteer import build_gazetteer
from ml.datasets.build_off_italy import build_off_italy


def test_gazetteer_output_contract(tmp_path):
    src = tmp_path / "merchants_seed.csv"
    src.write_text("raw_name,merchant_type\nConad Superstore S.r.l.,supermarket\n", encoding="utf-8")
    out = tmp_path / "merchant_gazetteer.csv"
    n = build_gazetteer(str(src), str(out), source="seed-test")
    assert n == 1
    with open(out, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert set(rows[0]) == {"raw_name", "normalized_name", "merchant_type", "source"}
    assert rows[0]["normalized_name"] == "conad superstore"
    assert rows[0]["merchant_type"] == "supermarket"


def test_off_italy_output_contract(tmp_path):
    src = tmp_path / "products_seed.csv"
    src.write_text(
        "product_name,brands,categories_tags\nPasta Barilla,Barilla,en:pasta\n",
        encoding="utf-8",
    )
    out = tmp_path / "off_italy_products.parquet"
    n = build_off_italy(str(src), str(out), version="test")
    assert n == 1
    table = pq.read_table(out)
    assert set(table.column_names) >= {"product_name", "brands", "categories_tags"}
    assert table.num_rows == 1
