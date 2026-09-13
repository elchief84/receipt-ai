"""Merchant/product name normalization shared by builders and composer.

Single spec for the tokenizer contract (see ARCHITECTURE.md risk 1):
lowercase → deaccent → strip legal forms/addresses → drop punctuation →
collapse whitespace. The Dart port must implement the same steps.
"""

import re
import unicodedata

MERCHANT_TYPES = [
    "supermarket",
    "food_shop",
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
    "food_shop": "groceries",
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


IT_STOPWORDS = frozenset(
    """
    il lo la i gli le un uno una un
    di a da in con su per tra fra
    del dello della dei degli delle
    al allo alla ai agli alle
    dal dallo dalla dai dagli dalle
    nel nello nella nei negli nelle
    sul sullo sulla sui sugli sulle
    col coi che se come piu meno
    non si ci ne mio tuo suo nostro vostro
    questo questa questi queste quello quella
    sono hai hanno siamo siete era erano stato
    l e ed ma o od anche solo gia piu
    """.split()
)


def tokenize(text: str) -> list:
    """Tokenizer spec v2: normalize → split → drop 1-char → drop stopwords."""
    return [
        t
        for t in normalize_name(text).split(" ")
        if len(t) >= 2 and t not in IT_STOPWORDS
    ]
