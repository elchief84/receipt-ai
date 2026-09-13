"""Build the Italian merchant gazetteer from a seed CSV (or OSM extract).

Input columns: raw_name, merchant_type (closed list, see normalize.MERCHANT_TYPES)
Output columns: raw_name, normalized_name, merchant_type, source
"""

import argparse
import csv

from .normalize import MERCHANT_TYPES, normalize_name


def build_gazetteer(src_csv: str, out_csv: str, source: str = "seed") -> int:
    count = 0
    with open(src_csv, encoding="utf-8") as fin, open(
        out_csv, "w", newline="", encoding="utf-8"
    ) as fout:
        reader = csv.DictReader(fin)
        writer = csv.DictWriter(
            fout,
            fieldnames=["raw_name", "normalized_name", "merchant_type", "source"],
        )
        writer.writeheader()
        for row in reader:
            mtype = row["merchant_type"].strip()
            if mtype not in MERCHANT_TYPES:
                raise ValueError(f"merchant_type not in closed list: {mtype!r}")
            writer.writerow(
                {
                    "raw_name": row["raw_name"].strip(),
                    "normalized_name": normalize_name(row["raw_name"]),
                    "merchant_type": mtype,
                    "source": source,
                }
            )
            count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="src", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--source", default="seed")
    args = parser.parse_args()
    n = build_gazetteer(args.src, args.out, args.source)
    print(f"wrote {n} merchants to {args.out}")


if __name__ == "__main__":
    main()
