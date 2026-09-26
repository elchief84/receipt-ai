from ml.evaluation.ocr_benchmark import cer, wer


def test_cer_identical_is_zero():
    assert cer("CONAD 10.60", "CONAD 10.60") == 0.0


def test_cer_counts_edits_over_reference_length():
    assert cer("abd", "abc") == 1 / 3


def test_cer_empty_reference_is_zero():
    assert cer("anything", "") == 0.0


def test_wer_counts_word_edits():
    assert wer("latte intero", "latte intero") == 0.0
    # one wrong word out of two
    assert wer("latte rotto", "latte intero") == 0.5


def test_wer_normalizes_punctuation_and_case():
    assert wer("CONAD, 10.60", "conad 10 60") == 0.0
