# Riepilogo Benchmark Verifica Formale (AMM)

Questo documento fornisce una mappatura completa dello stato dell'arte del benchmark di verifica formale applicato alle quattro versioni del contratto AMM. Suddivide e classifica le versioni del contratto, le regole scritte per testarle, la copertura dei test pratici (Forge) e confronta i risultati dei due prover formali (Certora e SolCMC) rispetto alla Ground Truth.

---

## 1. Evoluzione delle Versioni del Contratto

Questa tabella illustra l'evoluzione incrementale della sicurezza del contratto AMM, da un'implementazione "naif" a una pronta per la produzione.

| Versione | Profilo | Difetti / Vulnerabilità Principali | Risoluzioni |
| :--- | :--- | :--- | :--- |
| **AMM_v1** | *Sicura (Production-ready)* | Nessuna nota | Sincronizza i saldi flessibilmente contro i Donation DoS, aggiunge `nonReentrant` e upper bounds. |
| **AMM_v2** | *Ibrida (Matematicamente Perfetta)* | Donation DoS (uguaglianza stretta `balance == r0`), Reentrancy | Fissa Liveness, Inflation Attack, Price Truncation e aggiunge Swap Fee (0.3%). |
| **AMM_v3** | *Naif* | Inflation Attack, Liveness Bug (impossibile prelevare 100%), Donation DoS, Assenza Fee, Reentrancy | - |
| **AMM_v4** | *Disastrosa (Didattica)* | Infinite Dilution (prezzo = x0+x1), Price Truncation (manca 1e18), Unbounded Redeem (drenaggio totale) | Rimuove (per sbaglio) il Liveness Bug originale togliendo i check di sicurezza. |

---

## 2. I 4 Pilastri della Sicurezza Verificata

Le 10 proprietà testate non sono state scelte a caso, ma coprono sistematicamente i 4 pilastri delle vulnerabilità DeFi negli Automated Market Maker:

1. **Precisione Matematica e Scaling**: Verifica che la matematica intera della EVM non distrugga il valore economico tramite troncamenti a zero o overflow. Valida il corretto scaling (`1e18`) dei prezzi per prevenire furti di precisione.
2. **Sicurezza Economica e Tokenomics**: Garantisce che le regole finanziarie non siano manipolabili. Dimostra matematicamente la difesa contro l'Inflation Attack (tramite `MINIMUM_LIQUIDITY`), l'incremento rigoroso della fee e l'equità proporzionale dei prelievi di fronte a donazioni di token extra.
3. **Vulnerabilità Operative e Blocchi (DoS & Liveness)**: Assicura che i fondi non possano rimanere bloccati (frozen) a causa di attacchi logici. Smaschera deadlock operativi (come l'uso di `<` al posto di `<=`) e attacchi DoS causati dall'invio malevolo di token diretti al contratto.
4. **Integrità dello Stato Globale**: Dimostra che le fondamenta algebriche del contratto non possano mai collassare, garantendo che le riserve non possano mai essere drenate completamente una volta inizializzate, mantenendo vivo il mercato.

---

## 3. Tassonomia delle Proprietà

| # | Proprietà | Pilastro | Categoria (Skeleton) | Tipo | Descrizione |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | **deposit-precision** | 1 (Precisione) | Function Spec | Safety | Assicura che un deposito ragionevole (>= 0.1%) non generi zero azioni (shares) a causa di perdite di precisione. |
| 1b | **deposit-precision-strict** | 1 (Precisione) | Function Spec | Safety | Dimostrazione (Didattica) che l'uso dell'uguaglianza stretta `==` fallisce a causa degli errori di arrotondamento della divisione EVM. |
| 2 | **donation-dos** | 3 (DoS & Liveness) | Function Spec | Liveness | Verifica che la funzione di prelievo non si blocchi per colpa di un invio malevolo (donazione) diretto al contratto. |
| 3 | **minimum-liquidity** | 2 (Sicurezza Econ.) | State Invariant | Safety | Verifica che almeno 1000 token di liquidità siano permanentemente bloccati all'address 0 per mitigare attacchi di inflazione. |
| 4 | **price-bounds** | 1 (Precisione) | Function Spec | Safety | Valida il fattore di scaling `1e18` in base al "principio di scarsità" relativo delle riserve. |
| 5 | **price-equality** | 1 (Precisione) | Function Spec | Safety | Se le riserve dei due token sono identiche, il prezzo calcolato del token deve essere esattamente `1e18`. |
| 6 | **price-symmetry** | 1 (Precisione) | Function Spec | Safety | Dimostra che il prodotto incrociato dei prezzi non ecceda `1e36`, evitando overflow. |
| 7 | **redeem-fairness** | 2 (Sicurezza Econ.) | Function Spec | Safety | Verifica che l'ammontare prelevato sia matematicamente proporzionale ai bilanci reali del contratto, ridistribuendo le donazioni extra. |
| 8 | **redeem-liveness** | 3 (DoS & Liveness) | Function Spec | Liveness | Garantisce che l'ultimo fornitore di liquidità possa prelevare il suo 100% senza che la transazione vada in revert. |
| 8b | **redeem-precision** | 1 (Precisione) | Function Spec | Safety | Verifica che se un utente brucia delle shares, riceva sempre un ammontare > 0 (o vada in revert). |
| 9 | **reserves-not-drained** | 4 (Integrità Stato) | State Invariant | Safety | Assicura che le riserve di una pool inizializzata rimangano strettamente maggiori di 0 (impossibile drenare totalmente). |
| 10 | **swap-fee** | 2 (Sicurezza Econ.) | Function Spec | Safety | Verifica che dopo uno swap il prodotto costante (k) aumenti rigorosamente a causa della tassa (fee). |
| 11 | **constant-product** | 4 (Integrità Stato) | Function Spec | Safety | Dopo uno swap, il prodotto matematico dei bilanci reali (K = balance0 * balance1) non deve mai diminuire. |
| 12 | **swap-precision** | 1 (Precisione) | Function Spec | Safety | Scambiare una quantità non nulla di token deve restituire una quantità non nulla, evitando la perdita di precision a zero. |

---

## 4. Copertura Testing Concreto (Forge)

Oltre alla prova formale astratta, alcuni comportamenti sono stati validati concretamente sulla EVM tramite Forge per cristallizzare le vulnerabilità e i "Proof of Concept" (PoC).

| # | Proprietà | Testata in Forge? | Dettagli / PoC Associato |
| :- | :--- | :---: | :--- |
| 1 | **deposit-precision** | ❌ No | Nessun PoC esplicito presente per testare il troncamento delle shares. |
| 1b | **deposit-precision-strict** | ✅ Sì | `deposit-precision-strict_v1.t.sol`: dimostra il falso positivo (rounding error) con quantità indivisibili. |
| 2 | **donation-dos** | ✅ Sì | `donation-dos_v2.t.sol`: dimostra il freeze permanente inviando 1 wei alla pool. |
| 3 | **minimum-liquidity** | ✅ Sì | Dimostrazione pratica dell'Inflation Attack (tramite script correlato a depositi). |
| 4 | **price-bounds** | ❌ No | Nessun PoC presente. |
| 5 | **price-equality** | ✅ Sì | `price-equality_v4.t.sol` e `price-equality_v1.t.sol`: dimostrano il bug di troncamento a zero sulla v4 e la sua risoluzione sulla v1. |
| 6 | **price-symmetry** | ❌ No | Nessun PoC presente. |
| 7 | **redeem-fairness** | ✅ Sì | `redeem-fairness_v4.t.sol` e `redeem-fairness_v1.t.sol`: dimostrano la perdita del capitale donato sulla v4, e la sua corretta redistribuzione sulla v1. |
| 8 | **redeem-liveness** | ✅ Sì | `redeem-liveness_v3.t.sol`: dimostra il deadlock della vittima sulla v3. |
| 8b | **redeem-precision** | ✅ Sì | `redeem-precision_v4.t.sol`: dimostra il furto di shares per arrotondamento a zero. |
| 9 | **reserves-not-drained** | ✅ Sì | `reserves-not-drained_v4.t.sol`: mostra il furto del 100% della liquidità. |
| 10 | **swap-fee** | ✅ Sì | `swap-fee_v3.t.sol` e `swap-fee_v1.t.sol`: dimostrano la deviazione del prodotto k in assenza di trattenuta sulla v3, e il rigido incremento sulla v1. |
| 11 | **constant-product** | ✅ Sì | `constant-product_v4.t.sol`: dimostra il crollo matematico del prodotto k quando le riserve memorizzate non vengono aggiornate (drenaggio di valore). |
| 12 | **swap-precision** | ✅ Sì | `swap-precision_v1.t.sol`: dimostra il furto per arrotondamento (zero return) scambiando 1 wei. |

---

## 5. Matrice dei Risultati (Ground Truth vs Prover)

La tabella definitiva che confronta le aspettative umane (Ground Truth) con le performance effettive degli analizzatori formali.
*(Legenda: ❌ = Proprietà Violata / Buggata ; ✅ = Proprietà Verificata / Sicura)*

| Proprietà | Tool | v1 | v2 | v3 | v4 | Note SolCMC / Certora |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **deposit-precision** | *Ground Truth* | ✅ | ✅ | ❌ | ❌ |  |
| | **Certora** | ✅ | ✅ | ❌ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce v2/v1 per loop abstraction (ciclo while della radice quadrata). |
| **deposit-precision-strict** | *Ground Truth* | ❌ | ❌ | ❌ | ❌ | (Falso Positivo atteso ovunque per l'errore di arrotondamento). |
| | **Certora** | ❌ | ❌ | ❌ | ❌ | Allineato al fallimento atteso. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Allineato al fallimento atteso. |
| **donation-dos** | *Ground Truth* | ✅ | ❌ | ❌ | ✅ |  |
| | **Certora** | ✅ | ❌ | ❌ | ✅ | Perfettamente allineato. Isola in modo netto v2 vs v1. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Essendo una proprietà Liveness `try/catch`, fallisce ovunque. |
| **minimum-liquidity** | *Ground Truth* | ✅ | ✅ | ❌ | ❌ |  |
| | **Certora** | ✅ | ✅ | ❌ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce v2/v1 per array aliasing e astrazione cicli. |
| **price-bounds** | *Ground Truth* | ✅ | ✅ | ✅ | ❌ |  |
| | **Certora** | ✅ | ✅ | ✅ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ✅ | ❌ | Supporta benissimo le disuguaglianze lineari, ma fallisce su loop. |
| **price-equality** | *Ground Truth* | ✅ | ✅ | ✅ | ❌ |  |
| | **Certora** | ✅ | ✅ | ✅ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ✅ | ❌ | Opera bene sull'algebra lineare, ma fallisce se c'è astrazione loop. |
| **price-symmetry** | *Ground Truth* | ✅ | ✅ | ✅ | ✅ |  |
| | **Certora** | ✅ | ✅ | ✅ | ✅ | Perfettamente allineato. |
| | **SolCMC** | ✅ | ✅ | ✅ | ✅ | Allineato! (Algebra pura su getter). |
| **redeem-fairness** | *Ground Truth* | ✅ | ✅ | ✅ | ❌ |  |
| | **Certora** | ✅ | ✅ | ✅ | ❌ | Conferma che solo calcolando sui bilanci reali (v2/v1) si distribuiscono le donazioni. v3 passa "a vuoto" per via del revert finale. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce ovunque a causa della dipendenza da external calls (`this.redeem`). |
| **redeem-liveness** | *Ground Truth* | ✅ | ✅ | ❌ | ✅ |  |
| | **Certora** | ✅ | ✅ | ❌ | ✅ | Allineato dopo aver isolato il DoS (`balance0 == r0`). |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce ovunque a causa della mancata astrazione sui path liveness/external calls. |
| **redeem-precision** | *Ground Truth* | ✅ | ✅ | ❌ | ❌ |  |
| | **Certora** | ✅ | ✅ | ❌ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce ovunque per colpa delle external calls. |
| **reserves-not-drained** | *Ground Truth* | ✅ | ✅ | ✅ | ❌ |  |
| | **Certora** | ✅ | ✅ | ✅ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Falsi positivi generati da chiamate esterne / memoria. |
| **swap-fee** | *Ground Truth* | ✅ | ✅ | ❌ | ❌ |  |
| | **Certora** | ✅ | ✅ | ❌ | ❌ | Perfettamente allineato. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce a causa dell'inlining mancante (astrazione). |
| **constant-product** | *Ground Truth* | ✅ | ✅ | ✅ | ❌ |  |
| | **Certora** | ✅ | ✅ | ✅ | ❌ | Perfettamente allineato. Identifica la gravissima vulnerabilità di v4. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Fallisce (Timeout) su V1-V3 a causa dell'esplosione di stati durante lo swap, ma riesce a trovare la vulnerabilità su V4? (Da verificare) |
| **swap-precision** | *Ground Truth* | ❌ | ❌ | ❌ | ❌ | (Fallimento atteso, la divisione intera ruba sempre token infinitesimi) |
| | **Certora** | ❌ | ❌ | ❌ | ❌ | Allineato al fallimento atteso. |
| | **SolCMC** | ❌ | ❌ | ❌ | ❌ | Allineato al fallimento atteso. |
