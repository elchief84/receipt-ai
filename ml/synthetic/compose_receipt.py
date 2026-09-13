"""Italian receipt composer: real slots + receipt templates + OCR noise.

Record contract (tested seam):
  merchant{raw_name, normalized_name, merchant_type}, date, items[],
  amount{total, currency}, category, ocr_text
"""

import argparse
import csv
import json
import random

from ml.datasets.normalize import (
    abbreviate,
    default_category_for_merchant_type,
    normalize_name,
)

_OCR_SUBS = {"o": "0", "O": "0", "l": "1", "I": "1", "e": "c", "a": "4", "A": "4"}


def add_ocr_noise(text: str, rng: random.Random, error_rate: float = 0.06) -> str:
    out = []
    for ch in text:
        if ch in _OCR_SUBS and rng.random() < error_rate:
            out.append(_OCR_SUBS[ch])
        else:
            out.append(ch)
    noisy = "".join(out)
    return noisy if noisy != text else text + " "


def load_seeds(merchants_csv: str, products_csv: str, fixture: bool = False) -> dict:
    if fixture:
        merchants = [
            {"raw_name": "Conad Superstore", "merchant_type": "supermarket"},
            {"raw_name": "Eni", "merchant_type": "fuel"},
            {"raw_name": "Amazon", "merchant_type": "ecommerce"},
        ]
        products_by_category = {
            "groceries": [
                {"product_name": "Latte Intero 1L", "price": 1.49},
                {"product_name": "Pasta Barilla 500G", "price": 1.29},
            ],
            "transport": [{"product_name": "Benzina 10L", "price": 18.50}],
            "technology": [
                {"product_name": "Cuffie Bluetooth", "price": 29.99},
                {"product_name": "Cavo USB-C 1M", "price": 9.99},
            ],
            "shopping": [
                {"product_name": "Maglietta Cotone M", "price": 12.90},
                {"product_name": "Lampadina LED E27", "price": 4.50},
            ],
        }
        return {"merchants": merchants, "products_by_category": products_by_category}

    merchants = []
    with open(merchants_csv, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            merchants.append(
                {
                    "raw_name": row["raw_name"].strip(),
                    "merchant_type": row["merchant_type"].strip(),
                }
            )
    products_by_category: dict = {}
    with open(products_csv, encoding="utf-8") as f:
        for i, row in enumerate(csv.DictReader(f)):
            cat = (row.get("category") or "other").strip()
            price = 1.0 + (i % 25) + ((i * 37) % 100) / 100.0
            products_by_category.setdefault(cat, []).append(
                {"product_name": row["product_name"].strip(), "price": price}
            )
    return {"merchants": merchants, "products_by_category": products_by_category}


def _pick_merchant(rng: random.Random, merchants: list, force: str | None) -> dict:
    if force:
        for m in merchants:
            if normalize_name(m["raw_name"]) == normalize_name(force):
                return m
        raise ValueError(f"unknown merchant: {force!r}")
    return rng.choice(merchants)


def compose_record(
    rng: random.Random,
    seeds: dict,
    force_merchant: str | None = None,
    force_category: str | None = None,
) -> dict:
    merchant = _pick_merchant(rng, seeds["merchants"], force_merchant)
    mtype = merchant["merchant_type"]
    category = force_category or default_category_for_merchant_type(mtype)

    pool = seeds["products_by_category"].get(category) or [
        p
        for plist in seeds["products_by_category"].values()
        for p in plist
    ]
    n_items = rng.randint(1, 4)
    items = []
    for _ in range(n_items):
        prod = rng.choice(pool)
        qty = rng.choice([1, 1, 1, 2, 3])
        unit = round(prod["price"] * rng.uniform(0.9, 1.1), 2)
        items.append(
            {
                "raw_description": prod["product_name"],
                "quantity": qty,
                "unit_price": unit,
                "total": round(qty * unit, 2),
            }
        )
    total = round(sum(i["total"] for i in items), 2)
    day = rng.randint(1, 28)
    month = rng.randint(1, 12)
    record = {
        "merchant": {
            "raw_name": merchant["raw_name"],
            "normalized_name": normalize_name(merchant["raw_name"]),
            "merchant_type": mtype,
        },
        "date": f"{day:02d}/{month:02d}/2026",
        "items": items,
        "amount": {"total": total, "currency": "EUR"},
        "category": category,
        "ocr_text": "",
    }
    clean = render_text(record)
    lines = clean.split("\n")
    body = [add_ocr_noise(line, rng) for line in lines[2:-1]]
    record["ocr_text"] = "\n".join([lines[0], lines[1], *body, lines[-1]])
    return record


def render_text(record: dict) -> str:
    lines = [record["merchant"]["raw_name"], record["date"], ""]
    for item in record["items"]:
        desc = abbreviate(item["raw_description"]).ljust(24)[:24]
        lines.append(f"{desc} {item['total']:7.2f}")
    lines.append("")
    lines.append(f"TOTALE {record['amount']['total']:.2f}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--merchants", required=True)
    parser.add_argument("--products", required=True)
    parser.add_argument("--n", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    seeds = load_seeds(args.merchants, args.products)
    with open(args.out, "w", encoding="utf-8") as f:
        for _ in range(args.n):
            f.write(json.dumps(compose_record(rng, seeds), ensure_ascii=False) + "\n")
    print(f"wrote {args.n} records to {args.out}")


if __name__ == "__main__":
    main()
