# Receipt AI

Laboratorio MVP per classificare spese italiane da documenti fotografati, solo con dati pubblici e derivati. Pipeline: documento → OCR → transazione → merchant normalization → classificazione → UI.

## Language

**Transaction**:
Una singola spesa estratta da un documento, con data, merchant, importo e classificazione.
_Avoid_: Purchase, Order, Payment

**Merchant**:
Il venditore riportato sul documento, distinto da cosa è stato comprato.
_Avoid_: Brand, Shop, Vendor

**merchant_type**:
Cosa vende abitualmente il venditore (es. supermarket, fuel, pharmacy). Non implica la categoria di spesa.
_Avoid_: Category, Merchant category

**expense_category**:
Tipologia di spesa della transazione (taxonomy v2: groceries, restaurants, transport, health, shopping, technology, leisure_travel, services, other).
_Avoid_: Merchant type, Merchant category

**OCR text**:
Testo grezzo estratto dal documento, con possibili errori di riconoscimento.
_Avoid_: Receipt text, Scan

**Classification**:
Assegnazione di una expense_category a una Transaction, con confidence e model_version.
_Avoid_: Categorization, Labeling

**Confidence**:
Stima del modello sulla correttezza della classificazione (high / medium / low da soglie configurabili).
_Avoid_: Score, Probability

**Unknown**:
Stato di una riga item che il modello non ha saputo classificare (confidence sotto soglia). Non è una expense_category: è mostrato come "Sconosciuta" e invitato alla correzione, che alimenta il Feedback.
_Avoid_: Other ("capito, non rientra"), shopping (mai come fallback)

**Feedback**:
Correzione dell'utente registrata come dato per futuro retraining, mai applicata online al modello.
_Avoid_: Retraining, Online learning

**Debug corpus**:
Foto reali dell'utente, in cartella locale `debug/` gitignored, usate solo per diagnosi/eval locale (ADR-0011). Mai training, mai commit.
_Avoid_: Golden set, Test set
