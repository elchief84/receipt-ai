# Tecniche e algoritmi per l'estrazione strutturata da scontrini italiani

Obiettivo: da una foto di uno scontrino italiano (layout non standardizzato tra registratori/stampanti fiscali diverse), estrarre in modo affidabile:
- Nome e indirizzo dell'esercente
- Elenco articoli acquistati con prezzo singolo
- Totale della spesa

Di seguito le tecniche, divise per fase della pipeline, dalla più semplice/economica alla più sofisticata.

---

## 1. Preprocessing dell'immagine (prima ancora dell'OCR)

La qualità dell'input è spesso il collo di bottiglia principale (carta termica sbiadita, pieghe, foto storta, ombre).

- **Document scanning / crop automatico**: usare un modulo di document detection (es. ML Kit Document Scanner su Android, VisionKit su iOS) per ritagliare il documento e correggere la prospettiva prima dell'OCR.
- **Deskew**: raddrizzare il testo se la foto non è perfettamente frontale (rilevamento angolo tramite trasformata di Hough sulle linee di testo).
- **Binarizzazione adattiva**: algoritmi come Otsu o Sauvola/Niblack (quest'ultimo migliore su sfondi non uniformi come la carta termica ingiallita) per separare testo da sfondo.
- **Denoising e sharpening**: filtri morfologici (erosione/dilatazione) per pulire il rumore residuo della stampa termica.
- **Super-resolution leggera** (opzionale): se le foto sono a bassa risoluzione, modelli di super-resolution mobile-friendly (es. ESRGAN quantizzato, o modelli ancora più leggeri tipo FSRCNN) possono migliorare la leggibilità dei caratteri piccoli.

---

## 2. Motore OCR

Opzioni realistiche per uso on-device:

| Motore | Note |
|---|---|
| **ML Kit Text Recognition v2** (Google) | Gratuito, on-device, buon supporto multilingua, restituisce bounding box per riga e per blocco — fondamentale per gli step successivi |
| **Apple Vision Framework** (`VNRecognizeTextRequest`) | Equivalente nativo iOS, anch'esso con bounding box |
| **Tesseract (tesseract.js / TesseractOCR mobile)** | Open source, più configurabile ma generalmente meno accurato su testo piccolo/stampa termica rispetto a ML Kit |
| **PaddleOCR mobile (PP-OCR)** | Molto usato in ambito receipt/document understanding, modelli quantizzati pensati per mobile, spesso più accurato di Tesseract su documenti reali |

**Nota importante**: qualunque motore tu scelga, assicurati di ottenere non solo il testo ma anche le **coordinate (bounding box) di ogni riga/parola** — sono la base per tutte le tecniche di parsing strutturato descritte sotto.

---

## 3. Dall'OCR grezzo ai campi strutturati

Qui si dividono due filosofie: euristica (regole) e machine learning (modelli). In pratica il miglior risultato si ottiene combinandole.

### 3.1 Approccio euristico/regex (base solida, veloce da implementare)

- **Partita IVA come ancora stabile**: `\b\d{11}\b` preceduto spesso da "P.IVA"/"P.I." — è un formato standard nazionale, indipendente dal layout. Usarla per identificare univocamente l'esercente indipendentemente da errori OCR sul nome.
- **Indirizzo**: regex su pattern tipici italiani, es. `(via|viale|corso|piazza|vicolo|largo)\s+[\wàèéìòù'\.\s]+\d+` seguito da CAP (`\b\d{5}\b`) e città. Gli indirizzi hanno una struttura abbastanza regolare da intercettare con poche regex combinate.
- **Data**: `\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}`.
- **Totale**: keyword matching con **fuzzy string matching** (distanza di Levenshtein ≤ 1-2, via librerie come RapidFuzz) su varianti tipo "TOTALE", "TOTALE EURO", "TOT.", per tollerare errori OCR da stampa sbiadita ("T0TALE", "TOTAI E"). Tra i candidati vicini alla keyword, scegli l'importo più in basso nella pagina/il più grande.
- **Righe articolo**: raggruppa i token OCR per riga usando la coordinata Y del bounding box (clustering per fascia orizzontale), poi dividi ogni riga in **descrizione + prezzo** cercando un pattern di importo (`\d+[,\.]\d{2}`) verso la fine della riga.
- **Validazione incrociata**: somma i prezzi degli articoli estratti e confronta col totale rilevato — se la differenza supera una soglia, marca lo scontrino per revisione manuale invece di fidarti ciecamente del parsing.

### 3.2 Segmentazione righe/tabelle senza template

Poiché non esiste un layout comune, evita template a posizione fissa. Meglio:
- **Clustering per riga (row grouping)**: raggruppare i bounding box OCR in righe basandosi sulla sovrapposizione verticale (Y), poi ordinare per X — funziona indipendentemente dal font o dalla stampante.
- **Rilevamento colonna prezzo**: nella maggior parte degli scontrini i prezzi sono allineati a destra; identificare la colonna dei prezzi come il cluster di bounding box la cui X destra è più costante tra le righe (allineamento a destra), poi tutto ciò che sta a sinistra nella stessa riga è la descrizione articolo.

### 3.3 Classificazione per riga con un piccolo modello (più robusto, generalizza meglio)

Invece di sole regole fisse, addestra un classificatore leggero che etichetta ogni riga OCR come `{nome_esercente, indirizzo, riga_articolo, totale, data, altro}`, usando come feature:
- Il testo della riga (embedding leggero, anche solo TF-IDF o char n-gram)
- Feature posizionali: posizione Y normalizzata (0=alto, 1=basso), altezza del testo (spesso il nome negozio ha font più grande), presenza di cifre, presenza di simbolo €/virgola decimale
- Sequenza: usare un modello sequenziale semplice (BiLSTM-CRF o anche solo un CRF classico su feature manuali) così la predizione di una riga tiene conto del contesto delle righe vicine (es. "la riga subito sopra al totale è quasi sempre l'ultimo articolo")

Questo approccio è quello che generalizza meglio su layout mai visti, perché impara pattern *relativi* e non posizioni assolute.

### 3.4 Modelli di Key Information Extraction (KIE) più avanzati

Se vuoi spingerti oltre (più complesso, ma è materiale forte per un articolo tecnico):
- **LayoutLM / LayoutLMv3**: modelli transformer che combinano testo, posizione e (opzionalmente) immagine per l'estrazione di campi da documenti — pensati esattamente per casi come scontrini/fatture. Pesanti per mobile puro, ma si possono usare in fase di training/labeling automatico del dataset, poi distillare un modello piccolo per il device.
- **Donut (Document Understanding Transformer)**: approccio "OCR-free" — un modello vision-to-sequence che legge direttamente l'immagine e genera un JSON strutturato, saltando lo step OCR classico. Interessante concettualmente, ma il modello base è pesante per l'inferenza on-device; esistono varianti più piccole ma richiedono comunque valutazione attenta su hardware mobile.
- **Approcci a grafo (Chargrid, PICK, SPADE)**: modellano il documento come un grafo dove i nodi sono i token OCR e gli archi rappresentano relazioni spaziali; una rete neurale a grafo (GNN) classifica poi i nodi per tipo di campo. Buoni risultati su documenti a layout molto vario, ma complessità implementativa alta per un progetto "non troppo complicato".

**Raccomandazione pratica**: parti da 3.1 + 3.2 (euristica + row clustering), che risolve già l'80% dei casi con sforzo contenuto; usa 3.3 come miglioramento incrementale se vuoi generalizzare meglio; considera 3.4 solo se il progetto cresce oltre l'esperimento iniziale.

---

## 4. Correzione e apprendimento continuo

- **Post-OCR spell correction**: dizionario/gazetteer di nomi prodotto e catene di negozi comuni in Italia, per correggere errori OCR plausibili (distanza di edit minima verso un termine noto).
- **Human-in-the-loop**: quando la confidenza di un campo è bassa, mostra il campo editabile invece di fallire silenziosamente. Ogni correzione dell'utente diventa un nuovo esempio di training: nel tempo il modello di riga (3.3) migliora sui layout che l'utente incontra davvero.
- **Cache per esercente**: una volta identificato correttamente un esercente (via P.IVA), memorizza il layout tipico dei suoi scontrini (es. dove si trova il totale, formato del nome) per velocizzare/migliorare le letture future dello stesso negozio.

---

## 5. Vincoli per l'esecuzione on-device

- **Formato modello**: TensorFlow Lite (Android) o Core ML (iOS) per qualunque componente ML (classificatore di riga, correttore, ecc.); quantizzazione int8 per ridurre dimensione e latenza.
- **Motore OCR**: preferire soluzioni già ottimizzate per mobile (ML Kit, Vision Framework, PaddleOCR-mobile) piuttosto che eseguire modelli OCR pesanti generici.
- **Bilanciare accuratezza e peso**: i modelli KIE avanzati (LayoutLM, Donut) sono utili soprattutto in fase di sviluppo/labeling automatico del dataset di training, non necessariamente da eseguire in produzione sul telefono.

---

## 6. Metriche di valutazione

- **Field-level F1** per ciascun campo (nome esercente, indirizzo, articolo, prezzo, totale)
- **Exact match rate** sul totale (è il campo più critico da avere corretto)
- **Character Error Rate / Levenshtein normalizzato** per i campi testuali (nome, indirizzo, descrizione articolo)
- **Consistency check rate**: percentuale di scontrini in cui somma articoli ≈ totale rilevato (buon proxy di qualità complessiva della pipeline)