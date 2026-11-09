# SPLICE RUSH — istruzioni per l'agente di sviluppo

Questo file è la fonte di verità per te, agente. Leggilo per intero a inizio sessione. Se una richiesta dell'utente lo contraddice, vince l'utente: segnala la contraddizione in una riga e prosegui.

## 1. Cosa stai costruendo

SPLICE RUSH (titolo di lavoro) è un arena brawler verticale (9:16), free-to-play, pensato per diventare virale su TikTok. Un match dura 90 secondi.

- 12 combattenti (umani e bot) in un'arena a blocchi distruttibile.
- Ogni personaggio ha 4 slot: Testa, Braccia, Gambe, Nucleo. Chi sconfigge un avversario ne fa cadere un pezzo; chi lo raccoglie se lo attacca addosso e si trasforma visibilmente.
- Chi accumula pezzi rari diventa l'Abominio: più grande, segnalato a tutti, braccato da tutti.
- Nessuna eliminazione: se muori perdi un pezzo e rientri dopo 3 secondi.
- Monetizzazione: solo cosmetici. Mai vantaggi di gioco.
- Piattaforme: web (link dai video), Android, iOS, desktop, da un solo progetto Godot.

Documenti di riferimento (se mancano, chiedili all'utente):

- `docs/GDD.md`: il game design document (esporta il doc "GDD — SPLICE RUSH" in Markdown).
- `docs/art/key-art.png`: il riferimento visivo di stile (vedi sezione 4).

## 2. Regole non negoziabili

1. **Server autoritativo.** Il client invia solo input. Posizioni, danni, drop, inventario, valute e acquisti sono decisi dal server. Nessun segreto o valore economico nel client: un client decompilato non deve valere nulla.
2. **Niente pay-to-win.** Nessun acquisto cambia danno, velocità, cooldown o forza dei pezzi. Niente loot box a pagamento con esito casuale.
3. **Verticale 9:16 sempre**, anche su desktop (colonna centrale). Una registrazione schermo deve essere già un TikTok.
4. **Attrito zero.** Dal tap sul link al primo input in meno di 8 secondi (obiettivo da misurare). Niente account obbligatorio: si parte come ospite.
5. **Bot in ogni lobby.** Il match parte in meno di 3 secondi anche con zero giocatori online. I bot sono segnalati con un'icona, mai spacciati per umani.
6. **Tono spicy ma non esplicito.** Nessun sangue né violenza realistica: i pezzi sono cartoon, gommosi o robotici. Target 12+.
7. **Nessuna proprietà intellettuale altrui.** Niente asset, nomi, personaggi o font di terzi senza licenza verificata. I riferimenti (Minecraft, Halo, Brawl Stars, Pokémon, Roblox) valgono per le meccaniche, non per l'aspetto.
8. **Nessuna stringa hardcoded.** Testi in file di traduzione (italiano di default, inglese subito dopo).
9. **Accessibilità di base.** Forme oltre ai colori (daltonismo), tremolio dello schermo disattivabile, controlli rimappabili.
10. **Non dichiarare mai che qualcosa funziona se non l'hai eseguito.** Vedi sezione 7.

## 3. Stack e skill da usare

Engine: **Godot 4.7** (baseline della repo di skill). Linguaggio: GDScript tipizzato.

Installa le skill (una volta): `npx skills add gamedev-skills/awesome-gamedev-agent-skills`

Il router riconosce l'engine da `project.godot`, quindi crea prima il progetto Godot, poi chiedi i compiti in linguaggio naturale. A inizio di ogni compito scrivi in una riga quali skill carichi e perché. Se il router non le carica, leggi tu la `SKILL.md` giusta prima di scrivere codice.

| Compito | Skill da caricare |
| --- | --- |
| Struttura del progetto, scene, segnali | `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups` |
| Arena 3D, camera fissa, luci, ambiente, post-processing, blocchi | `godot-3d-essentials`, `camera-systems`, `level-design` |
| Movimento, combattimento, joystick virtuale, WASD, gamepad | `godot-physics`, `physics-tuning`, `input-systems` |
| Dati dei pezzi (slot, rarità, effetti, cosmetici) | `godot-resources` |
| Animazioni di furto e trasformazione, game feel | `godot-animation`, `game-feel` |
| Look: toon, rim light, contorni, glow, raggio di luce | `godot-shaders`, `shader-programming` |
| Bot | `game-ai`, `ai-behavior-trees-utility-ai` |
| HUD e menu verticali, safe area | `godot-ui-control`, `game-ui-ux` |
| Audio e musica adattiva | `godot-audio`, `audio-design` |
| Multiplayer | `godot-multiplayer` |
| Salvataggio locale da ospite | `save-systems` |
| Asset coerenti (modelli, icone, UI art) | `create-game-assets` |
| Prestazioni web e mobile | `performance-optimization` |
| Prototipo, test, build | `prototype-fast`, `godot-gdscript-headless-testing`, `godot-export`, `itch-publish` (build giocabile per i tester) |

Skill da NON usare come base: `fps-shooter`, `roguelike`, `survival-crafting` (il gioco è un brawler, non un FPS né un roguelike a turni), `steam-publish` (non ora). `roblox-simulator-economy` è per Roblox: usala solo come ispirazione per curve di costo e pacing, non copiarne codice.

**Cosa le skill NON coprono** (backend con inventario e account, acquisti in-app, matchmaking, analytics, live ops, registrazione clip, link brevi, pubblicazione sugli store): per queste usa la documentazione ufficiale della tecnologia scelta, non inventare API, verifica le versioni e scrivi nel riepilogo le assunzioni fatte. Prima di scegliere lo stack del backend chiedi all'utente (sezione 9).

## 4. Direzione artistica: segui il key art

Il riferimento è `docs/art/key-art.png`. È un concept, non una specifica: l'obiettivo è la stessa sensazione, non la copia pixel per pixel. Il key art prevale sul GDD per l'aspetto: il GDD parlava di rig 2D, qui il rendering è **3D low-poly**, mentre la logica di gioco resta sul piano (vedi sezione 5).

**Inquadratura**

- Camera fissa ad angolo alto, circa 55–65 gradi verso il basso, prospettiva leggermente grandangolare, mai ruotata.
- Il personaggio del giocatore è il soggetto in primo piano, nella metà bassa del frame verticale; l'arena si apre in profondità dietro di lui.
- La zona dei pollici (circa il 35% inferiore) resta libera da HUD.

**Personaggi**

- Corpi blocchettosi, in stile voxel/low-poly, con testa grande, mani e piedi sovradimensionati, arti spessi. La silhouette deve restare leggibile a 40 pixel di altezza.
- Ogni combattente ha un colore base riconoscibile (nel key art: rosso, blu, verde, arancione; il protagonista ha una maglia viola con emblema a corona).
- I pezzi sono mesh separate agganciate a socket del corpo, così lo scambio è un cambio di mesh. Esempi dal key art: pugno enorme, motosega arancione, gamba-razzo a strisce rosso e bianco con fiamma, occhio laser rosso.
- Contorno scuro leggero sui personaggi e sui pezzi per la leggibilità, non sull'ambiente. Valuta l'inverted hull o un passaggio di post-processing con `godot-shaders`.
- La rarità si legge con forma e bagliore, non solo con il colore.

**Arena**

- Piattaforme fluttuanti di lastre di pietra crepate, rocce viola, rovine con un vessillo a corona in pixel.
- Barriere a strisce giallo-nere come ostacoli e pericoli.
- Piedistallo esagonale al centro con un cubo "?" e una colonna di luce dorata verticale: è la Power Part (compare ogni 25 secondi).
- Blocchi distruttibili con detriti cubici che volano e nuvole di polvere all'impatto.

**Palette (approssimata: campiona i colori dall'immagine prima di fissarli)**

| Uso | Colore indicativo |
| --- | --- |
| Cielo e ambiente | Viola-blu saturo, circa #6B4EFF–#8B5CF6, con nuvole |
| Rocce e lastre | Viola-lavanda desaturato, circa #7A6BB0 e #5B4B8A |
| Accento logo e UI | Rosa magenta, circa #FF2E93 |
| Energia e loot | Oro-arancio, circa #FFB020 e #FF8A00 |
| Pericolo | Giallo-nero, circa #FFC400 e #1A1A1A |
| Pannelli UI | Blu notte, circa #141432, con bordo chiaro sottile |

**VFX e juice**

- Impatto: stella luminosa bianco-gialla, linee di velocità, hit-stop breve.
- Raggi laser rossi, fiamma del razzo, scintille, polvere all'atterraggio.
- Trasformazione al furto: flash, rallentatore breve, squash e stretch, stinger audio riconoscibile. È il momento più clippabile del gioco: curalo prima di tutto il resto.
- Abominio: scala +50%, musica diversa, marker visibile a tutti.

**HUD e tipografia**

- HUD minimale in alto: timer al centro in un pannello blu notte con angoli smussati e icona di cronometro (es. 00:47); in alto a destra un pannello con le 4 icone degli slot e un contatore.
- Banner inclinati con testo corsivo in grassetto, contorno spesso (magenta per "DIVENTA L'ABOMINIO!") e corona nel marchio.
- Callout di tutorial con lo schema del corpo a 4 slot (pugno, stivale, testa, ingranaggio): si impara rubando, niente muri di testo.
- Font display con licenza libera verificata (per esempio OFL). Nessun font di marchi altrui.

**QA di stile (da fare a ogni traguardo visivo)**

1. Cattura uno screenshot del gioco in verticale.
2. Confrontalo con `docs/art/key-art.png`: angolo di camera, palette, leggibilità della silhouette, contorni, HUD, polvere e luce.
3. Elenca le differenze e correggi le due più evidenti prima di proseguire.
4. Allega lo screenshot al riepilogo.

**Piano B se il 3D è troppo pesante sul web.** Prima di produrre asset in serie fai lo spike tecnico della sezione 6. Se il peso del download o gli FPS non reggono nel browser, passa a sprite 2D pre-renderizzati dai modelli 3D: stesso stile, costo molto più basso. Non cambiare strada senza dirlo all'utente.

## 5. Architettura e convenzioni

```
project.godot
game/        client: scene, script, ui, vfx, audio, i18n
server/      logica del server di partita (Godot headless)
shared/      regole e dati condivisi client/server (tipi, costanti, PartData)
backend/     account, inventario, negozio, analytics (stack da decidere)
docs/        GDD.md, art/key-art.png, decisions/
tests/
```

- GDScript con tipi statici ovunque. Segnali verso l'alto, chiamate verso il basso.
- **Simulazione separata dalla presentazione.** La simulazione gira a tick fissi sul piano XZ (coordinate logiche 2D); il rendering 3D interpola. Questo semplifica server, rete e anti-cheat.
- Dati in `Resource`: `PartData` (slot, rarità, effetto, id cosmetico). Tutti i numeri di bilanciamento (danni, cooldown, raggi, soglie) in un file di bilanciamento, mai sparsi nel codice. I valori iniziali sono segnaposto da tarare.
- Il server tiene un **log eventi** del match: serve a ricostruire gli ultimi 15 secondi per la clip automatica a fine partita.
- Predizione locale per il proprio personaggio, interpolazione per gli altri. Frequenza di tick da tarare (ipotesi iniziale: 20–30 Hz).
- Test headless per la logica (`godot-gdscript-headless-testing`); l'export web deve poter essere eseguito da riga di comando (`godot-export`).
- Per il web verifica con `godot-export` il renderer richiesto (in genere serve Compatibility) e imposta il look di conseguenza.

## 6. Fasi e criteri di completamento

Procedi per fasi, una alla volta. Non anticipare la fase successiva.

| Passo | Compito | Fatto quando |
| --- | --- | --- |
| 0 | **Spike tecnico (2 giorni):** scena demo con 12 personaggi blocchettosi e arena, esportata sul web | Hai misurato peso del download, tempo al primo input su 4G, FPS su un telefono di fascia media e il comportamento nel browser interno di TikTok, e riportato i numeri |
| 1 | Progetto Godot, arena a griglia, personaggio con joystick virtuale e WASD, auto-attacco sul bersaglio più vicino | Si gioca a 60 FPS in verticale su web e mobile |
| 2 | Rig modulare a 4 slot e drop dei pezzi | Uccidi un bot, il pezzo cade, lo raccogli, il corpo cambia |
| 3 | 12 combattenti con bot (utility AI), match da 90 s, fase Frenzy con crollo dei bordi, risultato in 5 s, rivincita a un tap | Un match completo giocabile senza bug bloccanti |
| 4 | Game feel: hit-stop, shake leggero, animazione di trasformazione, stinger, kill-cam breve | La clip da 3 secondi del GDD è riproducibile e soddisfacente |
| 5 | Build web pubblicata per i tester | Link funzionante, numeri di peso e caricamento riportati |
| 6 | Registratore di clip: ultimi 15 secondi in 9:16 con link breve | Una clip esce dal gioco e si apre su un telefono |

Budget da validare (ipotesi, non verità): primo input entro 8 s da link su 4G, 60 FPS su telefoni di fascia media, download iniziale il più piccolo possibile (obiettivo indicativo sotto i 15 MB compressi, da confermare con la misura).

## 7. Come lavori

1. Per ogni compito: dichiara le skill che carichi, implementa in piccolo, esegui i test, avvia il gioco, fai lo screenshot, applica il QA di stile.
2. Commit piccoli e frequenti, con messaggi chiari.
3. A fine compito scrivi 3–5 righe: cosa è stato fatto, cosa hai misurato (numeri veri), quali assunzioni hai fatto, quali domande restano aperte. Allega gli screenshot.
4. Non inventare funzioni di Godot o di servizi esterni: se non sei sicuro, leggi la documentazione ufficiale o la skill, e dillo.
5. Se il compito richiede una scelta di design non coperta da GDD o da questo file, proponi due opzioni brevi e chiedi, invece di decidere in silenzio.

## 8. Cosa NON fare

- Niente logica di acquisto, valute o inventario nel client.
- Niente multiplayer in tempo reale prima che il match funzioni da solo contro i bot.
- Niente editor di arene, scambio tra giocatori, Sapori o Squad 3v3 in questa fase: sono previsti dopo il soft launch.
- Niente asset o testi copiati da giochi esistenti.
- Niente pubblicità forzate durante il match.
- Niente dark pattern: streak punitive, conti alla rovescia falsi, attese saltabili a pagamento.

## 9. Decisioni aperte (chiedi all'utente prima di implementarle)

1. **Contatore "4 / 6" nel key art:** non coincide con il GDD (l'Abominio richiede 4 pezzi di rarità almeno Rara, mentre la logline parla di sei pezzi rubati). Finché l'utente non decide, implementa i 4 slot e un contatore dei pezzi rubati nel match, senza soglia fissa.
2. **Rendering 3D o 2D:** decisione provvisoria 3D low-poly, da confermare o ribaltare dopo lo spike del passo 0.
3. **Stack del backend** (account, inventario, acquisti, analytics): da scegliere prima di iniziare `backend/`.
4. **Nome definitivo e marchio:** "SPLICE RUSH" è provvisorio e va verificato su store, marchi e domini.
