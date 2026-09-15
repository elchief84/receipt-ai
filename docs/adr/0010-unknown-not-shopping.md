# Unknown esplicito per item non classificati, mai shopping come fallback

Le righe item sotto soglia di confidence mostravano una categoria vuota.
Deciso: stato `unknown` esplicito ("Sconosciuta", riga tappabile per
correggere), distinto da `other` ("capito, non rientra in nessuna
categoria"). Vietato usare `shopping` (o altra categoria vera) come
cestino: corromperebbe riepilogo e futuri dati di training nascondendo
l'incertezza.

## Considered Options

- Blank (status quo ante) — scartato: l'utente non distingue "non ancora
  classificato" da un bug di rendering.
- `shopping` come default — scartato: categoria vera con significato
  statistico; inquina Summary e Feedback.
- `unknown` come classe del modello — scartato: "non so" non è
  apprendibile come categoria; resta stato di presentazione derivato
  dalla confidence, fuori da taxonomy e training data.

## Consequences

`ItemClassification.category` resta nullable; la UI rende null come
"Sconosciuta" correggibile (feedback con `original_category: unknown`
+ descrizione riga — le correzioni più preziose per il retraining).
Summary mostra il conteggio "Voci da verificare" senza soldi (i totali
restano sotto la categoria di transazione: niente double-count).
