"""Eval harness: compose → per-merchant split → lookup baseline → report."""

import argparse
import json
import random

from .baseline_lookup import LookupClassifier, evaluate
from .split import per_merchant_split
from ml.synthetic.compose_receipt import compose_record, load_seeds


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--merchants", required=True)
    parser.add_argument("--products", required=True)
    parser.add_argument("--n", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--test-ratio", type=float, default=0.2)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    seeds = load_seeds(args.merchants, args.products)
    records = [compose_record(rng, seeds) for _ in range(args.n)]
    train, test = per_merchant_split(records, args.test_ratio, args.seed)
    report = evaluate(LookupClassifier().fit(train), test)
    report["n_train"] = len(train)
    report["n_test"] = len(test)
    report["train_merchants"] = sorted(
        {r["merchant"]["normalized_name"] for r in train}
    )
    report["test_merchants"] = sorted({r["merchant"]["normalized_name"] for r in test})
    with open(args.report, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(
        f"accuracy={report['accuracy']:.3f} f1_macro={report['f1_macro']:.3f} "
        f"train={len(train)} test={len(test)}"
    )


if __name__ == "__main__":
    main()
