"""Per-merchant split: no normalized_name shared between train and test.

This is the anti-memorization gate (ADR-0001/0003): the model must
generalize beyond "CONAD = groceries".
"""

import random


def per_merchant_split(
    records: list, test_ratio: float = 0.2, seed: int = 42
) -> tuple[list, list]:
    rng = random.Random(seed)
    by_merchant: dict = {}
    for rec in records:
        key = rec["merchant"]["normalized_name"]
        by_merchant.setdefault(key, []).append(rec)
    merchants = sorted(by_merchant)
    rng.shuffle(merchants)
    n_test = max(1, round(len(merchants) * test_ratio))
    test_names = set(merchants[:n_test])
    train, test = [], []
    for name in merchants:
        (test if name in test_names else train).extend(by_merchant[name])
    return train, test
