"""Merchant/product name normalization shared by builders and composer.

Single spec for the tokenizer contract (see ARCHITECTURE.md risk 1):
lowercase → deaccent → strip legal forms/addresses → drop punctuation →
collapse whitespace. The Dart port must implement the same steps.
"""

import re
import unicodedata

MERCHANT_TYPES = [
    "supermarket",
    "fuel",
    "pharmacy",
    "restaurant",
    "clothes",
    "home_store",
    "electronics",
    "hotel",
    "transport_service",
    "services",
    "ecommerce",
    "other",
]

_MERCHANT_TYPE_TO_CATEGORY = {
    "supermarket": "groceries",
    "fuel": "transport",
    "pharmacy": "health",
    "restaurant": "restaurants",
    "clothes": "shopping",
    "home_store": "shopping",
    "electronics": "technology",
    "hotel": "leisure_travel",
    "transport_service": "transport",
    "services": "services",
    "ecommerce": "shopping",
    "other": "other",
}

_LEGAL_FORMS = re.compile(
    r"\b(s\.?r\.?l\.?|s\.?p\.?a\.?|s\.?a\.?s\.?|s\.?n\.?c\.?)\b", re.IGNORECASE
)
_ADDRESS = re.compile(r"\s-\s.*$")
_STREET_NO = re.compile(r"\bvia\b.*$", re.IGNORECASE)

_ABBREV = [
    ("PASTA", "PST."),
    ("BARILLA", "BRL."),
    ("GRAMMI", "G"),
    ("GRAMMO", "G"),
    ("LITRO", "L"),
    ("LITRI", "L"),
    ("CHILOGRAMMO", "KG"),
    ("CHILOGRAMMI", "KG"),
]


def normalize_name(raw: str) -> str:
    text = raw.lower()
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = _LEGAL_FORMS.sub("", text)
    text = _ADDRESS.sub("", text)
    text = _STREET_NO.sub("", text)
    text = re.sub(r"[^a-z0-9 ]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\b\d+\b", "", text)
    return re.sub(r"\s+", " ", text).strip()


def abbreviate(text: str) -> str:
    out = text.upper()
    for full, short in _ABBREV:
        out = re.sub(rf"\b{full}\b", short, out)
    return out


def default_category_for_merchant_type(merchant_type: str) -> str:
    return _MERCHANT_TYPE_TO_CATEGORY.get(merchant_type, "other")
