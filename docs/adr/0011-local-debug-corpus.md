# Corpus di debug locale: foto reali ammesse solo per diagnosi, mai training

La diagnosi dei fallimenti OCR/layout richiede esempi reali che si rompono.
Non esistono scontrini RT italiani pubblici etichettati, e la data policy
(PROJECT.md) vieta i dati personali nel training. Deciso: una cartella
`debug/` **gitignored** contiene le foto reali dell'utente + i dump OCR
(testo e geometria) usati **solo** per diagnosi ed eval locale. Mai nel
repo, mai come training data, mai inviate in rete.

## Considered Options

- Solo pubblico/sintetico — scartato: senza un campione reale che fallisce
  la diagnosi e' cieca; il renderer sintetico (issue #18) arriva dopo.
- Committare le foto — scartato: viola privacy e data policy.
- `debug/` locale, non committata — scelto: sblocca la diagnosi senza
  toccare training ne' repo. La separazione sample/user data di PROJECT.md
  §18 resta rispettata.

## Consequences

- `.gitignore` contiene `debug/`; la procedura e il formato sono in
  `docs/debug-corpus.md`.
- I dump `[OCR-TEXT]`/`[OCR-GEOM]` esistono gia' (home_screen): diventano
  il formato di cattura ufficiale, esteso con confidence/angle/cornerPoints
  (issue #8).
- Vale per la diagnosi e l'eval locale; il training resta esclusivamente
  pubblico/sintetico.
