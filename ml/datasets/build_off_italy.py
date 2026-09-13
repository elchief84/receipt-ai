"""Filter Italian products from a seed CSV.

Seed input columns: product_name, brands, categories_tags
Output parquet columns: product_name, brands, categories_tags

Full OFF dump runs (DuckDB on food.parquet, cfr. DATASETS.md) feed this
same script via an identical CSV extract; the parquet contract is unchanged.
"""

import argparse
import csv

import pyarrow as pa
import pyarrow.parquet as pq


def build_off_italy(src_csv: str, out_parquet: str, version: str = "seed") -> int:
    names, brands, cats = [], [], []
    with open(src_csv, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            name = (row.get("product_name") or "").strip()
            if len(name) < 3 or len(name) > 120:
                continue
            names.append(name)
            brands.append((row.get("brands") or "").strip())
            cats.append((row.get("categories_tags") or "").strip())
    table = pa.table(
        {"product_name": names, "brands": brands, "categories_tags": cats}
    )
    pq.write_table(table, out_parquet)
    return table.num_rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="src", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--version", default="seed")
    args = parser.parse_args()
    n = build_off_italy(args.src, args.out, args.version)
    print(f"wrote {n} products to {args.out}")


if __name__ == "__main__":
    main()
