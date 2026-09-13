from ml.datasets.normalize import (
    MERCHANT_TYPES,
    normalize_name,
    abbreviate,
    default_category_for_merchant_type,
)


def test_normalize_strips_legal_forms_and_address():
    assert normalize_name("Conad Superstore S.r.l. - Via Roma 12") == "conad superstore"


def test_normalize_deaccents_and_lowercases():
    assert normalize_name("FARMACÌA Comunale") == "farmacia comunale"


def test_normalize_collapses_spaces_and_punct():
    assert normalize_name("  Eni,  Stazione  di  servizio! ") == "eni stazione di servizio"


def test_merchant_types_is_closed_list():
    assert set(MERCHANT_TYPES) == {
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
    }


def test_abbreviate_uses_receipt_style():
    assert abbreviate("PASTA BARILLA 500 GRAMMI") == "PST. BRL. 500 G"


def test_default_category_mapping():
    assert default_category_for_merchant_type("supermarket") == "groceries"
    assert default_category_for_merchant_type("food_shop") == "groceries"
    assert default_category_for_merchant_type("fuel") == "transport"
    assert default_category_for_merchant_type("pharmacy") == "health"
    assert default_category_for_merchant_type("restaurant") == "restaurants"
    assert default_category_for_merchant_type("electronics") == "technology"
    assert default_category_for_merchant_type("hotel") == "leisure_travel"
    assert default_category_for_merchant_type("services") == "services"
    assert default_category_for_merchant_type("ecommerce") == "shopping"
    assert default_category_for_merchant_type("unknown_type") == "other"
