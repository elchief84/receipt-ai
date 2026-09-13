/// Document gate (ADR-0008): the app only supports Italian RT fiscal
/// receipts (Registratore Telematico). Anything else gets an explicit
/// error instead of garbage output — unbounded document classes are what
/// made coverage unmeasurable.
library;

/// Strong markers: any one of these means fiscal receipt.
const _strongMarkers = [
  'documento commerciale',
  'registratore telematico',
  'scontrino fiscale',
  'n.scontr',
  'totale complessivo',
];

/// Weak markers: only count in pairs (e.g. P.IVA + TOTALE).
const _weakMarkers = [
  'p.iva',
  'piva',
  'totale',
  'iva',
  'contanti',
  'resto',
];

/// Web order fingerprints: online order summaries are explicitly OUT of
/// scope (best-effort dropped in ADR-0008). They share weak words
/// ("totale", "iva", "reso") with fiscal receipts, so they must be
/// rejected before the weak-pair rule can accept them.
const _webMarkers = [
  'riepilogo dell\'ordine',
  'venduto da',
  'metodo di pagamento',
  'costi di spedizione',
  'torna su',
  'condizioni generali',
];

bool isFiscalReceipt(String ocrText) {
  final norm = ' ${ocrText.toLowerCase()} ';
  if (_strongMarkers.any(norm.contains)) return true;
  if (_webMarkers.any(norm.contains)) return false;
  final weakHits = _weakMarkers.where(norm.contains).length;
  // Matricola RT: RT followed by 6+ digits.
  final hasMatricola = RegExp(r'\brt\b\D{0,10}\d{6,}').hasMatch(norm);
  return hasMatricola || weakHits >= 2;
}
