# Niente golden set manuale, holdout automatico

Niente trascrizione manuale di 150–300 scontrini: troppo costo. Il test `unknown-merchant` si fa con holdout automatico per merchant (nessun `normalized_name` del test nel train) + merchant sintetici perturbati + eval parser su CORD/WildReceipt. Si accetta una misura di domain shift più debole ma a costo zero.
