/// Bundled sample receipts (synthetic fiscal RT OCR text).
/// Every sample must pass the document gate (P.IVA + IVA lines included).
library;

const sampleReceipts = [
  (
    name: 'Conad',
    text: 'CONAD SUPERSTORE\nP.IVA 01234567890\n12/09/2026\n\nLATTE INTERO 1L          1.49\nPASTA BARILLA 500G       1.29\nBANANE KG 1.230          1.83\nDETERSIVO                5.99\n\nDI CUI IVA               1.60\nTOTALE COMPLESSIVO      10.60',
  ),
  (
    name: 'ENI',
    text: 'ENI STAZIONE DI SERVIZIO\nP.IVA 01234567890\n03/09/2026\n\nBENZINA SENZA PIOMBO   45.00\n\nDI CUI IVA               8.11\nTOTALE COMPLESSIVO      45.00',
  ),
  (
    name: 'Macelleria',
    text: 'MACELLERIA LA IMPERIALE SNC\nP.IVA 00808160535\n10/09/2026\n\nSALSICCIA KG 0.500       7.50\nCARNE MACINATA KG 0.300  5.40\n\nDI CUI IVA               1.19\nTOTALE COMPLESSIVO      12.90',
  ),
  (
    name: 'Farmacia',
    text: 'FARMACIA COMUNALE\nP.IVA 01234567890\n10/09/2026\n\nDENTIFRICIO MENTA 75ML    3.20\n\nDI CUI IVA               0.58\nTOTALE COMPLESSIVO       3.20',
  ),
  (
    name: 'Ristorante',
    text: 'PIZZERIA DA MICHELE\nP.IVA 01234567890\n05/09/2026\n\nPIZZA MARGHERITA          7.00\nCAPPUCCINO                1.50\n\nDI CUI IVA               0.77\nTOTALE COMPLESSIVO       8.50',
  ),
];
