# Logistic JSON embedded invece di TFLite

Status: supersede di ADR-0005 per la parte classifier (ML Kit resta per OCR).

Il LogisticRegression TF-IDF viene esportato come `classifier.json` (vocabolario + idf + coefficienti, 48KB) con inference in Dart puro, invece di conversione TFLite. Parità Python↔Dart esatta per costruzione (stesso tokenizer `normalize_name+split-v1`, test di parità in `tests/test_train.py`), niente plugin nativi, modello <100KB. Se un giorno vince un modello non-lineare si rivaluta TFLite/ONNX.
