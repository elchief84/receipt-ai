"""Unknown-merchant simulation: perturb merchant names (ADR-0003).

No manual golden set: test records get merchant names with realistic
typos/variants so normalized names never match the train gazetteer.
"""

import random

_SUBS = {"o": "0", "e": "c", "a": "4", "l": "1", "i": "1"}


def perturb_merchant(raw: str, rng: random.Random) -> str:
    chars = list(raw)
    i = rng.randrange(len(chars))
    op = rng.random()
    if op < 0.4 and chars[i].isalpha():
        chars[i] = chars[i] * 2  # Conad -> Conadd
    elif op < 0.7 and chars[i] in _SUBS:
        chars[i] = _SUBS[chars[i]]  # OCR-style typo
    else:
        chars.insert(i, rng.choice("aeiou"))  # vowel slip
    return "".join(chars)


def perturb_record(record: dict, rng: random.Random) -> dict:
    import copy

    from ml.datasets.normalize import normalize_name

    rec = copy.deepcopy(record)
    old_raw = rec["merchant"]["raw_name"]
    new_raw = perturb_merchant(old_raw, rng)
    if normalize_name(new_raw) == rec["merchant"]["normalized_name"]:
        new_raw = new_raw + "x"
    rec["merchant"]["raw_name"] = new_raw
    rec["merchant"]["normalized_name"] = normalize_name(new_raw)
    rec["ocr_text"] = rec["ocr_text"].replace(old_raw, new_raw, 1)
    return rec
