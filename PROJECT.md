# Project: Receipt & Expense Classification — ML + Flutter MVP

Voglio realizzare un progetto sperimentale completo per classificare automaticamente le spese a partire da documenti finanziari come:

- scontrini
- ricevute
- fatture
- documenti fotografati con lo smartphone
- eventualmente PDF

L'obiettivo NON è costruire un sistema contabile completo.

L'obiettivo è creare un MVP tecnico che dimostri questa pipeline:

    documento
        ↓
    OCR / text extraction
        ↓
    structured transaction
        ↓
    merchant normalization
        ↓
    expense category classification
        ↓
    mobile UI
        ↓
    "Come ho speso i miei soldi?"

## IMPORTANTISSIMO: DATA POLICY

Non possiedo dataset personali di scontrini o fatture.

Per questo progetto è VIETATO utilizzare dati personali/reali dell'utente come dataset di training.

Il training/evaluation deve utilizzare esclusivamente:

1. dataset pubblici con licenza compatibile;
2. dataset sintetici generati programmaticamente;
3. dati pubblici utilizzabili per costruire merchant/product/category dictionaries;
4. eventualmente documenti sintetici generati artificialmente.

Non progettare il sistema assumendo che in futuro avremo migliaia di scontrini reali.

Il progetto deve essere completamente riproducibile senza dati privati.

Quando valuti un dataset pubblico:
- verifica la licenza;
- documenta la provenienza;
- documenta eventuali limitazioni;
- non scaricare dataset con licenze incompatibili;
- crea un DATASETS.md con tutte le fonti utilizzate.

---

# 1. OBIETTIVO FUNZIONALE

Dato un documento come:

    CONAD SUPERSTORE
    12/09/2026

    LATTE INTERO 1L       1.49
    PASTA BARILLA 500G    1.29
    BANANE KG 1.230       1.83
    DETERSIVO             5.99

    TOTALE                10.60

il sistema dovrebbe produrre una transazione strutturata simile a:

{
  "date": "2026-09-12",
  "merchant": {
    "raw_name": "CONAD SUPERSTORE",
    "normalized_name": "conad",
    "merchant_type": "supermarket"
  },
  "amount": {
    "total": 10.60,
    "currency": "EUR"
  },
  "classification": {
    "category": "groceries",
    "confidence": 0.97
  }
}

Gli items possono essere estratti quando possibile, ma NON devono essere necessari
per classificare la transazione nel primo MVP.

---

# 2. PRINCIPIO ARCHITETTURALE

Non voglio un unico modello monolitico "receipt → category".

Voglio una pipeline modulare:

    Document
       ↓
    OCR / Parser
       ↓
    Transaction Extraction
       ↓
    Merchant Normalization
       ↓
    Expense Classification
       ↓
    Transaction

Ogni componente deve essere sostituibile.

Il sistema deve permettere di cambiare:
- OCR engine
- extraction strategy
- classifier
- model
- taxonomy

senza riscrivere tutta l'app.

---

# 3. CLASSIFICAZIONE

La classificazione deve essere principalmente a livello di TRANSAZIONE.

Esempio:

    CONAD → groceries
    ENI → transport
    FARMACIA → health
    PIZZERIA → restaurants

ma NON bisogna assumere che merchant = category.

Esempio importante:

    AMAZON
      può essere:
        electronics
        shopping
        family
        home
        ecc.

Quindi la classificazione deve poter utilizzare:

1. merchant name
2. normalized merchant
3. merchant type
4. OCR text
5. item descriptions, quando disponibili
6. eventuali segnali numerici
7. document metadata

---

# 4. TAXONOMY MVP v2 (ridotta 12 → 8+1)

Usa inizialmente una taxonomy piccola e non ambigua.

Proposta v2:

    groceries        // supermercati, alimentari (Conad, Esselunga, Coop)
    restaurants      // ristoranti, pizzerie, bar, fast-food
    transport        // carburante (Eni...), parcheggi, treni, mezzi pubblici
    health           // farmacie, parafarmacie, ottici, medici
    shopping         // abbigliamento, casa, ecommerce generico (incl. Amazon non-tech, Decathlon abbigliamento, IKEA casa)
    technology       // elettronica, informatica (MediaWorld, Apple, Amazon tech)
    leisure_travel   // merge di leisure+travel: hotel, voli, cinema, sport, musei
    services         // bollette, banca, parrucchiere, idraulico, assicurazioni
    other            // fallback, bassa confidence

Modifiche rispetto a v1:
- RIMOSSO `family`: non è una tipologia di spesa, è un beneficiario trasversale. Creava overlap con shopping/home/groceries.
- MERGE `leisure + travel` in `leisure_travel`: in italiano con pochi dati sono indistinguibili (hotel vs weekend vs cinema). Split possibile in v3 se F1 lo permette.
- MERGE `home` dentro `shopping`: IKEA/Leroy Merlin vs abbigliamento non sono separabili senza item-level. Se item-extraction migliora, ri-splittare.
- MANTENUTO `services` separato da `other`: bollette/utenze hanno pattern testuali molto distintivi (IVA, POD, fattura elettronica) e non vanno nel fallback.
- MANTENUTO `technology` separato da `shopping`: è il caso Amazon ambiguo, serve per testare merchant+items vs merchant-only.

NON creare centinaia di categorie.

La taxonomy deve essere configurabile in un unico punto del progetto.

Voglio poterla modificare facilmente.

Se durante la ricerca dei dataset emerge che una categoria è troppo ambigua o scarsamente rappresentata,
proponi una modifica prima di implementarla definitivamente.

---

# 5. MERCHANT CATEGORY ≠ EXPENSE CATEGORY

È fondamentale mantenere distinti:

    merchant_type

e

    expense_category

Esempio:

    merchant:
        name = Amazon
        type = ecommerce

    transaction:
        expense_category = technology

Oppure:

    merchant:
        name = Conad
        type = supermarket

    transaction:
        expense_category = groceries

Questa distinzione deve essere presente anche nel modello dati.

---

# 6. CONFIDENCE

Il classifier deve produrre una confidence.

Esempio:

{
  "category": "groceries",
  "confidence": 0.96
}

Prevedere almeno tre livelli logici:

    HIGH CONFIDENCE
    MEDIUM CONFIDENCE
    LOW CONFIDENCE

Non hardcodare necessariamente le soglie nel modello.

Devono essere configurabili.

Per le classificazioni a bassa confidence l'app Flutter deve poter chiedere conferma all'utente.

Esempio:

    "Ho classificato questa spesa come Tecnologia.
     È corretto?"

L'eventuale correzione dell'utente deve poter essere registrata come feedback.

Questo feedback NON deve automaticamente modificare il modello online.

Deve invece essere salvato come training/evaluation data per una futura fase di retraining.

---

# 7. ML STRATEGY

Non partire direttamente con un modello enorme.

Voglio una strategia sperimentale che permetta di confrontare:

A. rule-based baseline

B. merchant dictionary / lookup

C. classical ML baseline

D. transformer / modern text classifier, se giustificato

E. eventualmente un modello ibrido

Il progetto deve permettere di capire quale soluzione offre il miglior rapporto:

    accuracy
    complexity
    inference cost
    dataset requirements
    maintainability

Non assumere che il modello più grande sia il migliore.

---

# 8. DATASET

Cerca dataset pubblici realmente utilizzabili.

Possibili dati:

- receipt OCR datasets
- scanned receipt datasets
- synthetic receipts
- expense classification datasets
- merchant datasets
- product/category datasets
- public retail datasets

Se non esiste un dataset sufficiente per una parte del problema,
costruisci dati sintetici.

Il synthetic data generator deve essere parte del repository.

Deve poter generare esempi come:

    merchant
    date
    items
    prices
    discounts
    VAT
    subtotal
    total
    OCR noise
    category

Generare anche errori OCR realistici, ad esempio:

    CONAD → C0NAD
    BARILLA → BARlLLA
    LATTE → LATTE
    ESSELUNGA → ESSELUNGA

L'obiettivo è evitare che il modello funzioni soltanto su testo perfettamente pulito.

---

# 9. DATA MODEL

Definire uno schema comune.

Indicativamente:

Transaction

    id
    date
    merchant
    amount
    currency
    items[]
    classification
    source_document

Merchant

    raw_name
    normalized_name
    merchant_type

Classification

    category
    confidence
    model_version

Item

    raw_description
    normalized_description
    quantity
    unit_price
    total
    category (optional)

Non implementare necessariamente ogni campo nel primo MVP,
ma progettare il modello in modo estendibile.

---

# 10. MODEL OUTPUT

Il modello/classifier deve avere un'interfaccia semplice e stabile.

Idealmente qualcosa concettualmente simile a:

    classify(transaction_features)
        →
    ClassificationResult

con:

    category
    confidence
    model_version

L'app mobile NON deve conoscere i dettagli del modello ML.

---

# 11. INFERENCE

Voglio poter eseguire l'inference almeno in modalità locale/server-side durante il primo MVP.

Preferenza:

    Flutter app
        ↓
    simple API
        ↓
    ML service
        ↓
    classifier

Non è necessario costruire una vera infrastruttura cloud.

Durante lo sviluppo deve essere possibile eseguire tutto localmente.

Se è ragionevole, prevedere in futuro anche:

    Flutter
        ↓
    local/on-device model

ma NON è un requisito MVP.

Non complicare inutilmente il progetto.

---

# 12. API

Creare una piccola API per il prototipo.

Endpoint concettuale:

    POST /classify

Input:

    {
      "text": "...OCR text..."
    }

oppure un payload strutturato se preferibile.

Output:

    {
      "merchant": {...},
      "amount": {...},
      "classification": {
        "category": "groceries",
        "confidence": 0.96
      }
    }

Aggiungere:

    GET /health

e possibilmente:

    GET /categories

L'API deve essere documentata.

---

# 13. FLUTTER APP

Creare una piccola app Flutter esclusivamente per dimostrare il funzionamento del modello.

NON voglio un'app commerciale completa.

L'app deve avere pochissime schermate.

### Home

Mostrare:

    Expense Classifier

e due azioni:

    [Take photo]
    [Choose image]

Per MVP può anche essere presente:

    [Use sample receipt]

Questo è IMPORTANTISSIMO perché permette di testare il sistema senza avere documenti reali.

---

# 14. SAMPLE RECEIPTS

L'app deve includere alcuni documenti/scontrini sintetici di esempio.

Per esempio:

    Conad
    ENI
    Amazon
    Pharmacy
    Restaurant
    Decathlon

Possibilmente con risultati volutamente diversi.

L'utente può selezionare uno sample e vedere l'intero processo.

---

# 15. RESULT SCREEN

Dopo la classificazione:

    CONAD

    €73.42

    Groceries

    Confidence
    96%

    [Correct]
    [Change category]

Mostrare eventualmente:

    Merchant
    Date
    Total
    Category

Gli items possono essere mostrati se estratti.

---

# 16. FEEDBACK

Se l'utente cambia:

    Groceries → Shopping

registrare un feedback locale/server:

    original_category
    corrected_category
    transaction
    model_version
    timestamp

NON retrainare automaticamente.

Questo servirà in futuro per creare un dataset di feedback.

---

# 17. EXPENSE SUMMARY

Aggiungere una schermata minimale:

    This month

    Groceries       €412
    Restaurants     €185
    Transport       €143
    Shopping        €129
    Health           €74

Possibilmente con una semplice chart Flutter.

Questo dimostra il vero valore finale del progetto:

    "How did I spend my money?"

---

# 18. PRIVACY

Anche se utilizziamo solo dati sintetici/pubblici:

- non inserire dati personali nel repository;
- non inviare immagini a servizi esterni senza necessità;
- non inserire API keys;
- documentare chiaramente il flusso dei dati;
- separare sample data e user data.

---

# 19. REPOSITORY STRUCTURE

Proponi una struttura ragionevole.

Indicativamente:

    /ml
      /data
      /datasets
      /synthetic
      /training
      /evaluation
      /models
      /inference

    /backend
      /api
      /domain
      /services

    /mobile
      /lib
        /core
        /features
          /classification
          /transactions
          /summary

    /samples

    /docs

    README.md
    DATASETS.md
    MODEL.md
    ARCHITECTURE.md

La struttura definitiva può essere diversa se hai una motivazione tecnica migliore.

---

# 20. FLUTTER ARCHITECTURE

Usa una struttura semplice ma pulita.

Non introdurre Clean Architecture estremamente pesante per un MVP.

Preferenza:

    feature-oriented architecture

con separazione ragionevole tra:

    presentation
    application
    domain
    infrastructure

Usare dependency injection dove utile.

Il networking deve essere isolato.

Il classifier API client deve essere sostituibile.

---

# 21. TESTING

Voglio test automatici.

ML:

- dataset validation
- preprocessing tests
- classifier tests
- evaluation metrics

Backend:

- API tests
- parsing tests
- classification integration tests

Flutter:

- domain/application tests
- API client tests
- widget tests per le schermate principali

Non serve ottenere una coverage artificiosamente alta.

Preferisco pochi test significativi.

---

# 22. EVALUATION

Creare uno script che produca almeno:

    accuracy
    precision
    recall
    F1
    confusion matrix

e possibilmente metriche per categoria.

È importante capire se il modello funziona bene anche sulle categorie meno rappresentate.

Separare:

    training set
    validation set
    test set

Evitare data leakage, soprattutto nel caso di merchant ripetuti.

Se possibile, fare split per merchant in modo che il modello non impari semplicemente:

    "CONAD = groceries"

senza imparare a generalizzare.

Questo punto è molto importante.

Voglio testare sia:

### Known merchants

merchant presenti nel training.

### Unknown merchants

merchant mai visti durante il training.

Questo permette di capire se il modello sta realmente imparando a classificare la spesa oppure sta semplicemente memorizzando merchant names.

---

# 23. EXPERIMENT DESIGN

Prima di implementare un modello sofisticato, crea una baseline.

Esperimento 1:

    merchant lookup

Esperimento 2:

    TF-IDF + Logistic Regression / Linear classifier

Esperimento 3:

    modern text embedding/classifier

Confrontare:

    accuracy
    F1
    inference time
    model size
    complexity

Documentare i risultati in:

    MODEL.md

---

# 24. SYNTHETIC DATA GENERATOR

Questo è un componente importante.

Creare un generatore configurabile che possa produrre:

    1,000
    10,000
    100,000

transazioni sintetiche.

Ogni record deve avere:

    merchant
    merchant_type
    items
    amount
    category
    OCR text

Variare:

- merchant names
- product names
- prices
- formatting
- OCR errors
- missing fields
- abbreviations
- capitalization
- whitespace
- line ordering

Non generare dati completamente casuali senza struttura.

Il synthetic generator deve riflettere pattern plausibili degli scontrini.

---

# 25. IMPORTANT ML QUESTION

Voglio che tu valuti criticamente una cosa:

La classificazione dovrebbe usare:

    merchant only

oppure:

    merchant + OCR text

oppure:

    merchant + extracted items

oppure:

    tutto insieme?

Non assumere la risposta.

Implementa almeno una baseline che permetta di confrontare questi segnali.

L'obiettivo è capire quale informazione è realmente necessaria.

---

# 26. MVP DEFINITION

Il progetto MVP è completato quando posso fare:

    ./start.sh

o equivalente

e avere:

    ML/API server
        +
    Flutter app

Poi:

1. apro l'app;
2. scelgo uno sample receipt;
3. l'app invia il testo al backend;
4. il backend estrae/normalizza la transaction;
5. il classifier assegna una categoria;
6. l'app mostra merchant, amount, category e confidence;
7. posso correggere la categoria;
8. posso vedere un piccolo riepilogo delle spese.

Tutto deve funzionare localmente.

---

# 27. NON FARE

Non voglio:

- autenticazione
- utenti multipli
- pagamenti
- cloud deployment
- database distribuiti
- Kubernetes
- microservizi inutili
- LLM costosi chiamati ad ogni classificazione
- training su dati personali
- OCR proprietario a pagamento
- una UI complessa
- una taxonomy enorme
- overengineering

Questo è un laboratorio ML + mobile.

La qualità dell'esperimento è più importante della quantità di codice.

---

# 28. DELIVERABLES

Prima di scrivere molto codice, produci:

1. ARCHITECTURE.md
2. DATASETS.md
3. MODEL.md
4. README.md
5. struttura del repository
6. piano degli esperimenti
7. scelta motivata dei dataset pubblici
8. strategia synthetic data
9. API contract
10. Flutter screen flow

Poi implementa progressivamente.

---

# 29. WORKING METHOD

Procedi per fasi.

FASE 1
    Research + architecture

FASE 2
    Dataset acquisition/preparation

FASE 3
    Synthetic data generator

FASE 4
    Baseline classifier

FASE 5
    Evaluation

FASE 6
    API

FASE 7
    Flutter MVP

FASE 8
    Feedback loop

FASE 9
    Improvements

NON saltare direttamente alla fase 9.

Dopo ogni fase:

- esegui i test;
- verifica i risultati;
- aggiorna la documentazione;
- se una decisione architetturale si rivela sbagliata, correggila invece di costruirci sopra.

---

# 30. FIRST TASK

Per ora NON iniziare a implementare tutto.

Prima analizza il problema e restituiscimi:

1. architettura proposta;
2. struttura repository;
3. dataset pubblici che possiamo realmente utilizzare;
4. licenza di ogni dataset;
5. quali dataset usare per training/evaluation;
6. cosa generare sinteticamente;
7. taxonomy finale proposta;
8. baseline ML proposta;
9. stack tecnologico consigliato;
10. API design;
11. Flutter architecture;
12. piano delle fasi;
13. rischi tecnici principali.

Per ogni scelta importante dammi una motivazione.

Se trovi un punto ambiguo o una scelta che può cambiare significativamente il progetto, fermati e chiedimi prima di implementarlo.

L'obiettivo non è produrre tantissimo codice.

L'obiettivo è costruire un piccolo ma serio laboratorio per capire quanto bene possiamo classificare automaticamente le spese a partire da documenti finanziari, utilizzando esclusivamente dati pubblici e sintetici.