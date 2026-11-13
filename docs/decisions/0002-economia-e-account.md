# 0002 — Economia della stagione, guardaroba e collegamento account

Data: 2026-11-13 · Stato: implementato sul branch `feat/aspetto-impostazioni-economia` (solo
client e logica condivisa; il backend non esiste ancora)

## Contesto

Dopo negozio, skin e Season Pass l'economia era generosa: un nuovo giocatore partiva dal livello
34 con 1.204 monete, un giocatore assiduo free poteva comprare tutto il negozio in una stagione
(~5.800 monete guadagnate contro 2.850 di listino) e niente limitava la crescita delle skin
(~14 nuove a stagione → oltre 50 dopo quattro stagioni, verso le 150 temute dall'utente).

## Decisione

### 1. Ritmo delle monete (numeri in `shared/balance_config.gd` e `shared/economy_catalog.gd`)

| Voce | Prima | Ora |
| --- | --- | --- |
| Monete iniziali da ospite | 1.204 (profilo demo) | 250 (`STARTING_COINS`) |
| Livello pass iniziale | 34 | 1 |
| Monete a partita (base / kill / podio / vittoria) | più alte | 4 / 1 / 8 / 15 → ~6 a partita media, 19 vincendo |
| XP per livello pass | 900 | 1.000 |
| Monete nella traccia gratuita / Plus | — | ~814 / ~1.910 (10+3·n e 30+5·n, ×3 ogni 5 livelli) |
| Listino negozio (6 skin) | 2.850 | 3.800 (400–1.200) |

Modello di stagione (6 settimane, verificato da `test_economy_budget_new_guest_and_wardrobe_growth`):

- **Assiduo free** (8 partite al giorno, missioni fatte): ~3.250 monete a stagione, cioè ~85%
  del negozio. Deve scegliere: compra quasi tutto, mai tutto.
- **Casual** (3 partite al giorno): ~1.400 monete, 2–3 skin.
- **Prima skin**: 250 monete iniziali + ~25 partite, quindi entro il primo giorno di gioco
  vero. È l'aggancio: la prima vittoria economica arriva presto, poi il ritmo si distende.
- **Pass**: 39.000 XP; l'assiduo lo chiude in ~25 giorni, il casual in ~5–6 settimane. Chi
  gioca tanto finisce prima della fine stagione; chi gioca poco ci arriva per un pelo.

### 2. Guardaroba che non esplode

- Le skin sono raggruppate per **personaggio** (4 famiglie, "n/m stili"): con 15 skin
  l'Aspetto mostra 4 righe, non una griglia di 15.
- **Budget per stagione**: al massimo 4 skin nuove (`NEW_SKINS_PER_SEASON_MAX`), lancio con al
  massimo 15 (`LAUNCH_SKIN_COUNT_MAX`). Ogni skin ha un campo `season`; un test fallisce se una
  stagione sfora. Dopo 4 stagioni: ~31 skin, sempre in 4–6 famiglie.
- I **colori firma** (7, ognuno con forma propria per il daltonismo) sono collezionabili
  economici: 3 di base, 4 nel pass (gratis livelli 8 e 25, Plus 15 e 30).

### 3. Coerenza dell'Aspetto con il negozio

- Una skin non posseduta si **prova** sull'eroe ("PROVA"); il pulsante in basso diventa
  "COMPRA · prezzo" (stesso popup di conferma del negozio, sconto del giorno incluso) oppure
  "SBLOCCA · PASS LIV. n" per le skin del pass. Comprata, si indossa da sola.
- Pezzi iniziali e colore firma sono salvati nel profilo (`loadout`, `equipped_color_id`) e si
  vedono sull'eroe nel menu e in partita (anello sotto i piedi).

## Idee non implementate (da decidere)

1. **Livelli bonus dopo il 40** (es. 100 monete ogni 2.000 XP) per chi chiude presto il pass.
2. **Rotazione**: le skin del pass tornano in negozio dopo 2 stagioni, a prezzo pieno.
3. **Colori acquistabili** con monete come pozzo rinnovabile, senza toccare il gameplay.

## Account: piano con Firebase

Il client ha già l'interfaccia (`game/account/account_backend.gd`, `account_service.gd`) e i
pulsanti "Collega Google" / "Collega Apple" nelle impostazioni della home. Finché non c'è un
backend dicono onestamente "in arrivo" e il gioco resta da ospite (regola 4: attrito zero).

Piano proposto, da verificare sulla documentazione ufficiale prima di scriverlo:

1. Al primo avvio: **accesso anonimo** Firebase Auth; l'`uid` sostituisce il `guest_id` locale.
2. "Collega Google/Apple": **collegamento della credenziale** all'utente anonimo
   (link, non nuovo account), così l'`uid` e i progressi restano gli stessi.
3. Se la credenziale è già legata a un altro account: chiedere quale profilo tenere, mai
   unire in silenzio.
4. **Autorità sul server** (regola 1): monete, inventario, pass e acquisti vivono in Firestore
   e cambiano solo tramite Cloud Functions; le regole di sicurezza vietano scritture client su
   quei campi. Le ricevute di App Store / Google Play si validano lato server.
5. Il salvataggio locale resta come cache e per giocare offline da ospite.

Assunzioni da verificare (non ho controllato le API attuali):

- Il plugin/SDK Firebase per Godot 4.7 su web, Android e iOS (non esiste un SDK ufficiale per
  Godot: probabilmente REST di Firebase Auth sul web e plugin nativi su mobile).
- Requisiti Apple: su iOS, se offri l'accesso con Google devi offrire anche "Accedi con
  Apple"; i pulsanti devono seguire le linee guida di Apple e Google (gli attuali sono
  segnaposto testuali).
- Cancellazione dell'account dall'app (richiesta da App Store e Google Play quando esiste un
  account).

**Da cambiare quando arriva il backend:** il testo della privacy nelle impostazioni dice che
non raccogliamo dati; con un account collegato non sarà più vero.
