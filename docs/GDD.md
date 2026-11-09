# GDD — SPLICE RUSH (titolo di lavoro)

Nov 9, 2026 · @Giacomo Bertolazzi

## High concept

SPLICE RUSH è un arena brawler verticale da 90 secondi in cui ogni avversario sconfitto perde un pezzo del corpo, e tu te lo attacchi addosso: a fine match sei un mostro assurdo, costruito con i resti degli altri.

**Logline:** batti un avversario, gli rubi il braccio. Dopo 90 secondi sei un Abominio fatto di pezzi rubati e tutta l'arena ti dà la caccia.

**Pitch in tre righe**

- Un tap sul link del video e giochi nel browser, senza download né account.
- 12 combattenti (umani e bot) in un'arena distruttibile, un pollice, un match dura 90 secondi.
- Ogni kill cambia visibilmente il tuo corpo; chi indossa 4 pezzi rari diventa l'Abominio e viene braccato da tutti.

**La clip da 3 secondi.** Primo secondo: un omino normale con un braccio-pugno. Secondo secondo: ruba una gamba-razzo e decolla. Terzo secondo: atterra su un nemico con testa-laser e braccio-motosega, e il corpo si ricompone con un'animazione da meme. Chi guarda capisce regole, stakes e obiettivo senza audio e senza spiegazioni.

**Perché può fare la storia.** Tre idee lavorano insieme:

1. Il corpo è il tabellone: la progressione si legge a colpo d'occhio, senza HUD, quindi funziona in video compressi e in 3 secondi.
2. Ogni match produce un personaggio unico e irripetibile, quindi un contenuto unico da postare.
3. Gli stessi quattro slot del corpo sono la collezione (stile Pokémon) e il negozio cosmetico: si vende identità, non potere.

**Nota onesta.** Nessun GDD può garantire la viralità. Questo documento aumenta le probabilità con leve progettate e misurabili (sezione Motore di viralità) e prevede criteri go/no-go per fermarsi se i numeri non arrivano.

## Pilastri di design

Quattro pilastri guidano ogni decisione; se una feature non ne serve almeno uno, si taglia.

1. **Leggibile in un secondo.** La silhouette del personaggio racconta il suo stato: chi è forte, chi è cacciato, di che Sapore è.
2. **Ogni match è una storia.** Il caos emergente (pezzi che volano, arena che crolla) produce momenti diversi a ogni partita.
3. **Il corpo è progressione e negozio.** Pezzi, rarità e cosmetici vivono negli stessi quattro slot.
4. **Zero attrito.** Dal tap sul link al primo input in meno di 8 secondi, senza registrazione.

**Cosa prendiamo dai tuoi riferimenti**

| Riferimento | Cosa prendiamo | Come appare in SPLICE RUSH |
| --- | --- | --- |
| Minecraft | Emergenza, distruzione, creatività | Arena a blocchi distruttibili; editor di arene dopo il lancio |
| Halo | Momenti sandbox iconici, armi di potere a tempo | Power Part che compare ogni 25 s al centro, con annuncio sonoro |
| Brawl Stars | Match brevi, personaggi leggibili, mobile-first | Match da 90 s, un pollice, respawn rapido senza eliminazione |
| Pokémon Rosso/Verde/Blu | Collezione, tipi, scambio, rivalità | Mutadex dei pezzi, triangolo dei Sapori, scambio limitato, Nemesi |
| Roblox | UGC, piattaforma sociale, economia dei creator | Editor arene, skin dei creator con quota ricavi, Creator Codes |
| Meccha Chameleon | Trasformazione e mimetismo (interpretato) | Il corpo cambia forma a ogni kill; il mostro finale è irriconoscibile |

Nota: "Meccha Chameleon" non è un titolo che riconosco con certezza. L'ho interpretato come trasformazione e mimetismo; se intendevi altro, basta dirmelo e rivedo la riga.

**Cosa intendo per spicy.** Irriverente, veloce, un po' cattivo nel tono (rubare i pezzi agli altri, battute, rivalità), ma senza sangue né violenza realistica: i pezzi sono cartoon, gommosi o robotici. Serve anche per la policy degli store e di TikTok.

## Motore di viralità TikTok

Il gioco è progettato perché giocarlo e registrarlo producano già un TikTok: formato 9:16 nativo, clip automatiche e un link che riporta il guardante dentro la stessa sfida.

1. **Gameplay nativo 9:16.** Il gioco è verticale anche su desktop (colonna centrale). Una registrazione schermo riempie il frame di TikTok senza ritagli.
2. **Clip automatica a fine match.** Il gioco ricostruisce dal log eventi i 15 secondi migliori (multi-kill, trasformazione in Abominio, fail comico) e li esporta in 9:16 con barra del tempo, loop pulito e link breve. Un solo pulsante: Posta.
3. **Link-to-play con sfida.** Ogni clip contiene un link a un seed: chi lo apre gioca la stessa arena e prova a battere il mostro del video (ghost challenge). Niente login, ospite con salvataggio locale.
4. **Format di trend pronti.** Mostro del Giorno (stesso seed per tutti, hashtag fisso), Speedrun Abominio (secondi per diventare Abominio), Rate My Monster (stitch con il mostro di un altro).
5. **Creator come partner, non come pubblicità.** Creator Codes con quota sugli acquisti, skin co-firmate, lobby private per streamer, accesso anticipato alle mutazioni nuove.
6. **Momenti condivisibili per costruzione.** Kill-cam breve con zoom comico, replay al rallentatore del furto del pezzo, uno stinger audio riconoscibile pensato per diventare suono meme.

**Primi tre minuti (FTUE).** Link, poi primo input entro 8 s, prima kill entro 20 s, prima trasformazione visibile entro 30 s, prima clip proposta dopo la prima vittoria o la prima morte spettacolare. Nessun tutorial testuale: si impara rubando.

**Da verificare subito.** Molti link TikTok si aprono nel browser interno dell'app: serve testare WebGL, audio, schermo intero e tempo di caricamento in quell'ambiente prima di investire su altro. Se il caricamento supera i 5 secondi su 4G, si perde buona parte dei click.

**Metriche di viralità da misurare dal primo build.** Tasso di click-to-first-input, tasso di tap su Posta per match, clip effettivamente pubblicate, nuovi utenti per clip (K-factor). I target sono nella sezione Roadmap.

## Core gameplay

Il match dura 90 secondi, si gioca con un pollice e non esiste eliminazione: se muori perdi un pezzo e rientri dopo 3 secondi, così nessuno aspetta mai.

### Controlli

- **Mobile:** joystick flottante a sinistra, auto-attacco sul bersaglio più vicino, un pulsante a destra per l'abilità del pezzo (tap o trascina per mirare).
- **Desktop/web:** WASD o frecce per muoversi, mouse per mirare, clic per l'abilità.
- **Gamepad:** stick sinistro, un tasto abilità. Il rebind è previsto dall'inizio.

### Struttura del match (90 s)

| Fase | Tempo | Cosa succede |
| --- | --- | --- |
| Spawn | 0–5 s | 12 combattenti entrano nell'arena con i pezzi base |
| Scontro | 5–60 s | Chi sconfigge un avversario ne fa cadere un pezzo; si raccoglie camminandoci sopra |
| Frenzy | 60–90 s | L'arena crolla a blocchi dai bordi, le Power Part compaiono più spesso |
| Risultato | 90 s | Vince chi ha più Massa: valore dei pezzi indossati più kill |

### Corpo, slot e rarità

Ogni personaggio ha 4 slot; ogni pezzo ha una rarità (Comune, Raro, Epico, Leggendario) e un effetto visibile.

| Slot | Esempi di pezzo | Effetto |
| --- | --- | --- |
| Testa | Occhi laser, cupola scudo, magnete | Attacco a distanza, difesa, attrae i pezzi caduti |
| Braccia | Motosega, pugno-razzo, tentacolo | Arma principale |
| Gambe | Molle, ruote, propulsore | Mobilità e scatto |
| Nucleo | Pancia-bomba, aura, specchio | Abilità di area o utilità |

I valori numerici (danni, cooldown, raggi) sono segnaposto da bilanciare nel prototipo.

### Abominio e Bounty

Chi indossa 4 pezzi di rarità almeno Rara diventa l'Abominio: +50% di dimensione, la musica cambia, tutti vedono un marker sulla minimappa. Chi lo sconfigge ottiene 3 pezzi. È la meccanica di rimonta e il momento più clippabile del gioco.

**Decisione aperta.** Nel key art il contatore dell'HUD mostra "4 / 6": va deciso se rappresenta i pezzi rubati nel match o la soglia per diventare Abominio. Fino ad allora vale la regola sopra (4 pezzi di rarità almeno Rara).

### Arena

Griglia di blocchi distruttibili (omaggio a Minecraft), 4 temi a rotazione, una Power Part al centro ogni 25 secondi con annuncio audio (omaggio a Halo). La distruzione cambia il percorso e crea passaggi nuovi, quindi due match non sono mai uguali.

**Look dell'arena (dal key art).** Piattaforme fluttuanti di lastre di pietra crepate, rocce viola, rovine con un vessillo a corona, barriere a strisce giallo-nere. Al centro un piedistallo con un cubo "?" e una colonna di luce dorata segnala la Power Part.

### Sapori (dalla fase 2)

Triangolo di vantaggi in stile Pokémon: Piccante batte Dolce, Dolce batte Acido, Acido batte Piccante. Si attiva solo se i test mostrano che il match resta leggibile con la sola silhouette.

### Bot e matchmaking

Ogni lobby viene riempita di bot con utility AI, così il match parte in meno di 3 secondi anche con zero giocatori online. I bot sono segnalati con un'icona e non vengono spacciati per umani. Il livello dei bot scala con il livello del giocatore.

### Modalità

- **Frenzy 12:** la modalità principale.
- **Duello 1v1:** pensata per clip e sfide tra amici.
- **Squad 3v3:** socialità, dalla fase 2.
- **Mostro del Giorno:** stesso seed per tutti, classifica giornaliera.

## Meta loop e progressione

Quattro cicli annidati danno al giocatore un motivo per rientrare ogni giorno, ogni settimana e ogni stagione, e tutti pagano in pezzi e cosmetici dello stesso corpo.

| Orizzonte | Loop | Ricompensa |
| --- | --- | --- |
| Match (90 s) | Combatti, ruba, trasformati | Scrap (valuta soft), XP, pezzi nuovi |
| Giorno (3–5 match) | Missioni giornaliere, Mostro del Giorno | Cassa giornaliera deterministica, tentativo di record |
| Settimana | Missioni settimanali, obiettivi di Crew | Pezzi Rari garantiti, progressi sul Pass |
| Stagione (6–8 settimane) | Pass stagionale, ladder ranked, tema nuovo | Set cosmetici a tema, titoli, skin Abominio |

**Mutadex.** Il catalogo di tutti i pezzi (obiettivo iniziale: circa 120, cioè 30 per slot). Ogni pezzo va ottenuto almeno una volta per essere registrato; completare un set o una pagina sblocca cosmetici. È la leva Pokémon: collezionare, mostrare, completare.

**Nemesi.** Il gioco ricorda chi ti ha rubato un pezzo e lo segna nel match successivo. Rubare un pezzo al tuo Nemesi dà un bonus, e ogni furto è condivisibile come sfida diretta.

**Ranked.** Leghe da Bronzo a Leggenda con reset morbido a fine stagione. Le leghe alte sbloccano solo titoli e cornici, mai vantaggi di gioco.

**Crew.** Gruppi fino a 20 persone con obiettivi cooperativi settimanali e una chat limitata a emote e frasi rapide, che serve anche per moderazione e minori.

**Ritorni dopo l'assenza.** Chi manca da 3 giorni trova una Cassa del Ritorno con un pezzo scelto da lui, mai una penalità.

## Retention

La retention si costruisce su tre cose: un loop da 90 secondi che invita a "ancora uno", una collezione che non si finisce mai e motivi sociali per tornare domani.

**Meccaniche**

- **Ancora uno.** Nessuna schermata di attesa tra i match, risultato in 5 secondi, "rivincita" a un tap.
- **Fame di pezzi.** Ogni match fa cadere pezzi nuovi: c'è sempre qualcosa da completare nel Mutadex.
- **Rivalità.** Nemesi e sfide dirette dai link trasformano ogni sconfitta in un motivo per rigiocare.
- **Appuntamenti.** Mostro del Giorno, eventi a tempo del weekend, stagioni con tema nuovo ogni 6–8 settimane.
- **Social.** Crew, amici invitati dai link, classifica tra amici.
- **Notifiche con valore.** Solo con consenso: "il tuo Nemesi ti ha sfidato", "Mostro del Giorno pronto". Mai più di una al giorno.

**Obiettivi di partenza (ipotesi di settore, da validare in soft launch)**

| Metrica | Obiettivo minimo | Segnale forte |
| --- | --- | --- |
| Ritenzione D1 | 35% | 40% o più |
| Ritenzione D7 | 12% | 15% o più |
| Ritenzione D30 | 5% | 8% o più |
| Match per sessione | 4 | 6 o più |
| Sessioni al giorno | 2,5 | 3,5 o più |

**Limiti etici.** Il pubblico probabile include adolescenti: niente streak che puniscono chi salta un giorno, niente conti alla rovescia falsi, niente pulsanti per saltare l'attesa a pagamento, limiti di spesa e conferma sugli acquisti. Questo è anche ciò che gli store e i regolatori controllano di più.

## Monetizzazione basata su item

Si vende identità e prestigio, mai potere: ogni acquisto cambia come appare il mostro, non quanto è forte. Il gioco resta equo, quindi i clip restano credibili e la community non lo accusa di pay-to-win.

**Perché funziona anche contro pirateria e decompilazione.** Inventario, acquisti e progressione vivono solo sul server; il client è gratis e senza valore se copiato. Chi decompila il client non ottiene né item né vantaggi.

**Catalogo (prezzi indicativi, da testare)**

| Categoria | Esempi | Prezzo indicativo |
| --- | --- | --- |
| Skin dei pezzi | Set a tema (cyberpunk, gelato, medievale) | 2–8 € |
| Effetti di kill e trasformazione | Esplosione di coriandoli, glitch, fulmine | 3–6 € |
| Emote e pose di vittoria | Balletto, risata, mossa meme | 1–3 € |
| Skin Abominio leggendarie | Aura, forma gigante personalizzata | 10–15 € |
| Pass stagionale | Traccia gratis e traccia premium | 8–10 € |
| Starter pack (una tantum) | Skin, effetto e gemme | 1,99 € |
| Creator Skin | Skin co-firmate dai creator | 4–8 € |

**Valute.** Scrap (soft, si guadagna giocando) e Gemme (premium, si comprano). Le Gemme comprano solo cosmetici e il Pass.

**Negozio.** Rotazione giornaliera e settimanale con scarsità dichiarata onestamente ("torna fra N giorni"), un set in evidenza, una sezione evergreen. Per evitare le loot box a pagamento, il crafting è deterministico: fondi i doppioni e ottieni il cosmetico che vuoi.

**Creator Codes.** Il giocatore inserisce il codice di un creator e quest'ultimo riceve una quota sugli acquisti (percentuale da definire). Funziona come leva di distribuzione e come motivo per cui i creator portano il gioco.

**Pubblicità.** Solo video con ricompensa e facoltativi (raddoppia gli Scrap a fine match). Mai interstitial forzati durante il match.

**Scambio (dalla fase 2).** Solo cosmetici non vincolati, solo tra amici, con attesa di 24 ore, limite settimanale e commissione in Scrap che funge da sink. Richiede controlli antifrode: rischio di compravendita fuori piattaforma.

**Cosa NON si vende.** Danno, velocità, cooldown, pezzi più forti, accesso anticipato a pezzi che alterano il bilanciamento, loot box a pagamento con esito casuale. Le loot box sono regolate o vietate in alcuni Paesi e richiedono la dichiarazione delle probabilità negli store; vanno verificate con un legale se le vorrai davvero.

**Obiettivo di partenza (ipotesi).** 2–3% di paganti, con il primo acquisto (lo starter pack) entro i primi 7 giorni.

## UGC e creator economy

Dopo il lancio, il contenuto lo producono i giocatori: arene e skin create da loro mantengono il gioco fresco senza che lo studio debba produrre tutto (leva Roblox e Minecraft).

1. **Editor di arene (fase 3).** Griglia di blocchi, temi, punti di spawn e posizione delle Power Part. Una arena si pubblica come link o seed condivisibile in un clic.
2. **Voti e rotazione.** Le arene più votate entrano nella rotazione ufficiale, con il nome del creatore in sovrimpressione.
3. **Skin dei creator.** Il creator propone una skin, lo studio la rifinisce e la vende; il creator riceve una quota sui ricavi (percentuale da definire).
4. **Programma creator a livelli.** Micro creator ricevono accesso anticipato e codice; livelli più alti ricevono skin dedicate e lobby private.
5. **Moderazione.** Ogni contenuto UGC passa un controllo automatico prima della pubblicazione, più segnalazioni dalla community. Nessun testo libero nelle arene all'inizio.

## Direzione artistica e audio

Stile 3D low-poly blocchettoso e coloratissimo, visto da una camera alta e ispirato al key art di riferimento, con silhouette fortissime: deve restare leggibile dopo la compressione video di TikTok e su uno schermo da telefono.

- **Camera.** Fissa, ad angolo alto (circa 55–65 gradi), con prospettiva leggermente grandangolare e mai ruotata. Il personaggio del giocatore è in primo piano nella metà bassa del frame verticale e la zona dei pollici resta libera da HUD.
- **Personaggi modulari 3D.** Corpi blocchettosi con testa grande e mani e piedi sovradimensionati. I quattro slot sono mesh separate agganciate al corpo: cambiare un pezzo significa cambiare una mesh, quindi poche risorse e migliaia di combinazioni. Ogni combattente ha un colore base riconoscibile.
- **Palette.** Cielo viola-blu saturo, rocce viola-lavanda, magenta per logo e UI, oro-arancio per energia e loot, giallo-nero per i pericoli, pannelli blu notte. I valori esatti si campionano dal key art.
- **Tono.** Irriverente e umoristico, rating pensato per 12+: niente sangue, parti gommose, robotiche o fumettose.
- **Juice.** Hit-stop, stella luminosa all'impatto, polvere e detriti cubici, fiamma del razzo, screen shake leggero, squash e stretch. L'animazione di trasformazione è il momento centrale: è ciò che rende un clip "soddisfacente".
- **HUD.** Minimale: timer al centro in alto in un pannello blu notte, in alto a destra i quattro slot con un contatore, banner inclinati in corsivo grassetto e callout di tutorial con lo schema del corpo ("RUBA I PEZZI!"). Si impara rubando, senza muri di testo.
- **Audio.** Stinger riconoscibile per la trasformazione e per l'Abominio, annunciatore ironico, musica adattiva che accelera nella fase Frenzy. Pensato per funzionare anche senza audio, dato che molti guardano TikTok muto.
- **Accessibilità.** Forme oltre ai colori per i daltonici, effetti di tremolio disattivabili, sottotitoli per gli annunci, controlli rimappabili.

Per la produzione degli asset conviene bloccare subito un target visivo (il key art di riferimento, la palette, le regole delle silhouette) e generare i pezzi per famiglie coerenti, non uno alla volta. A ogni traguardo visivo si confronta uno screenshot del gioco con il key art: camera, palette, silhouette, contorni e HUD.

## Architettura tecnica

Un solo progetto Godot per web, mobile e desktop, con un server di partita autoritativo e servizi di backend che tengono tutto ciò che ha valore.

&#91;embedded content: architettura · client, server di partita, backend\]

Il client parla in tempo reale con il server di partita e con il backend per account, negozio e clip; solo il server scrive inventario e acquisti.

**Engine.** Godot 4.7 con rendering 3D low-poly e simulazione sul piano (la baseline della repo): un progetto esporta su web, Android, iOS e desktop, e la repo ha skill per 3D, multiplayer, export, shader e UI. Il rischio principale è il peso del 3D sul web, quindi prima di produrre asset si fa uno spike tecnico di 2 giorni: peso del download, tempo al primo input su 4G, FPS su un telefono di fascia media e comportamento nel browser interno di TikTok. L'obiettivo è il primo input entro 8 secondi da un link su 4G. Se i numeri non reggono, il piano B è usare sprite 2D pre-renderizzati dai modelli 3D (stesso stile, costo molto più basso) oppure, per la sola versione browser, un client web leggero con Phaser 4 o PixiJS (coperti anch'essi dalla repo), sullo stesso server.

**Server di partita.** Decide posizioni, danni e drop dei pezzi; il client invia solo input. Tick a frequenza fissa (ipotesi iniziale: 20–30 Hz da tarare), predizione locale per il proprio personaggio e interpolazione per gli altri. La simulazione gira sul piano con coordinate logiche 2D e il rendering 3D interpola, il che semplifica rete e anti-cheat. Con 12 combattenti lo stato è piccolo e la banda resta bassa.

**Account e inventario.** Si gioca subito come ospite con un ID anonimo; il progresso è salvato in locale e sul server. Il collegamento a un login (Apple, Google o altro) arriva dopo, per non perdere i progressi. Inventario, valute e acquisti sono scritti solo dal server.

**Acquisti.** IAP di Apple e Google nei client nativi e un pagamento web separato sul sito (regole da ricontrollare al momento del rilascio). Ricevute sempre validate sul server.

**Clip.** Il server conserva il log eventi; il client ricostruisce gli ultimi 15 secondi e li esporta in 9:16. Su web da prototipare con la cattura del canvas, su mobile con la cattura nativa. Va validato per primo, perché è la funzione che alimenta la viralità.

**Analytics.** Eventi fin dal primo build: click sul link, primo input, prima kill, fine match, tap su Posta, clip pubblicata, acquisto. Servono a decidere i gate della roadmap.

**Anti-cheat e pirateria.** Server autoritativo, limiti di frequenza sugli input, ricevute firmate. Un client decompilato non vale nulla senza il server.

**Costi.** Server attivi solo per le partite in corso, scalabilità automatica e un budget massimo giornaliero per non farsi sorprendere da un picco virale.

## Skill della repo e lacune

La [repo gamedev-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) copre bene engine, gameplay, feel, UI e asset su Godot 4.7; non copre backend, acquisti in-app, analytics e live ops, che vanno costruiti a mano o con altri strumenti.

Installazione indicata dalla repo: `npx skills add gamedev-skills/awesome-gamedev-agent-skills`. Il router riconosce l'engine dal file `project.godot`, quindi conviene creare prima il progetto Godot.

**Cosa coprono le skill**

| Compito nel gioco | Skill della repo |
| --- | --- |
| Struttura del progetto, scene, segnali | `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups` |
| Movimento, scatti, joystick | `godot-2d-movement`, `input-systems`, `physics-tuning` |
| Arena a blocchi distruttibili | `godot-3d-essentials`, `godot-physics`, `level-design` |
| Pezzi e dati (rarità, slot, effetti) | `godot-resources`, `godot-animation` |
| Bot | `game-ai`, `ai-behavior-trees-utility-ai` |
| Juice, camera, VFX | `game-feel`, `camera-systems`, `godot-shaders`, `shader-programming` |
| UI mobile, HUD verticale | `godot-ui-control`, `game-ui-ux` |
| Audio adattivo | `godot-audio`, `audio-design` |
| Salvataggio locale (ospite) | `save-systems` |
| Multiplayer | `godot-multiplayer` |
| Asset coerenti | `create-game-assets` |
| Prestazioni web/mobile | `performance-optimization` |
| Prototipo, test, build | `prototype-fast`, `godot-gdscript-headless-testing`, `godot-export` |
| Build giocabile su link per i tester | `itch-publish` |
| Idea di economia da adattare | `roblox-simulator-economy` (è per Roblox, ma utile per curve di costo e pacing) |

**Cosa NON coprono (da fare altrimenti)**

- Backend con inventario, economia, account ospite e login (Apple, Google, TikTok).
- Acquisti in-app (Apple, Google) e pagamenti web con validazione delle ricevute lato server.
- Matchmaking, server dedicati e scalabilità.
- Analytics, A/B test e live ops (shop a rotazione, eventi).
- Registrazione e codifica delle clip, deep link e short link.
- Pubblicazione sugli store, conformità legale, moderazione.

Le skill `fps-shooter`, `roguelike` e `survival-crafting` non servono come base: il gioco è un brawler top-down, non un FPS né un roguelike a turni.

## Roadmap e KPI

Cinque fasi e tre gate: se i numeri di un gate non passano, si corregge o ci si ferma prima di spendere sulla fase successiva.

&#91;embedded content: roadmap · 5 fasi, 3 gate\]

Le durate sono stime e i valori dei gate sono ipotesi di partenza, da rivedere dopo i primi test.

**Metriche di viralità (ipotesi da validare)**

- Click sul link che arrivano al primo input: almeno il 60%.
- Match che finiscono con un tap su Posta: almeno il 10%.
- Clip pubblicate rispetto ai tap su Posta: da misurare, nessun target iniziale.
- Nuovi utenti per clip pubblicata: in crescita da build a build; il target assoluto si fissa dopo il soft launch.

## Rischi e compliance

I rischi principali sono il cold start, i costi dei server e la tutela dei minori; tutti hanno una mitigazione già nel design.

| Rischio | Perché conta | Mitigazione |
| --- | --- | --- |
| Viralità non garantita | Un clip fortunato non è ripetibile | Molti format, creator seeding, criteri go/no-go |
| Cold start | Con pochi giocatori online il match non parte | Bot in ogni lobby, sfide fantasma |
| Costi server | Il picco virale può costare più di quanto incassi | Match brevi, limiti di CCU, scalabilità automatica, budget massimo giornaliero |
| Minori e privacy | Pubblico di adolescenti, GDPR e regole sui minori | Verifica d'età, niente pubblicità personalizzate, consenso dei genitori dove richiesto; da far verificare a un legale |
| Loot box | Regolate o vietate in alcuni Paesi | Nessun acquisto casuale a pagamento, crafting deterministico |
| Regole degli store | Gli acquisti digitali di norma richiedono l'IAP di Apple e Google; un'app che è solo un sito spesso viene respinta | Client nativo vero, validazione acquisti sul server, regole da ricontrollare al momento del rilascio |
| Regole di TikTok | Policy su annunci e contenuti, browser interno | Test del link nel browser interno, nessun contenuto violento esplicito |
| Chat e tossicità | Moderazione costosa e rischio per i minori | Solo emote e frasi rapide, segnalazione, niente chat libera |
| Barare | Rovina la fiducia e il negozio | Server autoritativo, limiti di frequenza, ricevute firmate |
| Cloni | I cloni compaiono in settimane | Vantaggio su live ops, collezione, community, creator |
| Proprietà intellettuale | I riferimenti sono marchi noti | Nessun asset, nome o personaggio copiato; solo meccaniche e ispirazioni |

Il nome "SPLICE RUSH" è provvisorio e va verificato su store, marchi e domini prima di spendere in branding.

## Prossimi passi

Il primo obiettivo è un prototipo giocabile in 2 settimane che risponda a una sola domanda: il furto dei pezzi è divertente da solo, senza il resto?

**Prompt iniziali per gli agenti** (da dare in ordine; il router carica le skill giuste; il file AGENTS.md del repo contiene regole e stile da seguire)

1. Crea un progetto Godot 4.7 con rendering 3D low-poly in formato verticale 9:16 e arena a griglia (prima uno spike tecnico: misura peso web, caricamento e FPS), personaggio con joystick virtuale e WASD, e auto-attacco sul bersaglio più vicino.
2. Aggiungi il rig modulare a 4 slot (Testa, Braccia, Gambe, Nucleo) e il drop dei pezzi: quando un personaggio muore, un suo pezzo cade a terra e si raccoglie camminandoci sopra.
3. Aggiungi 12 combattenti con bot a utility AI, match da 90 secondi, fase Frenzy con crollo dei bordi, schermata di risultato in 5 secondi e rivincita a un tap.
4. Aggiungi game feel: hit-stop, shake leggero, animazione di trasformazione, stinger audio, kill-cam breve.
5. Esporta una build web, misura peso e tempo di caricamento su 4G, e pubblicala su un link per i tester.
6. Prototipa il registratore di clip: ultimi 15 secondi in 9:16 con link breve.

**Appendice A: nomi alternativi** (tutti da verificare su marchi e store): FrankenBrawl, Glitchmob, Scrap Party, Muta Mob, Chimera Rush.

**Appendice B: cinque script di clip TikTok** (i primi 3 secondi sono il gancio)

1. *Ho rubato la gamba di un boss.* Il personaggio è minuscolo, ruba una gamba-razzo, decolla e piomba su tutti.
2. *Da zero ad Abominio in 40 secondi.* Contatore in sovrimpressione, ogni kill cambia il corpo, la musica cambia all'ultimo pezzo.
3. *Il mio bot mi ha rubato il braccio.* Fail comico, slow motion, zoom sulla faccia del bot.
4. *Rate my monster.* Il mostro del giorno mostrato a tutto schermo, invito a rispondere con il proprio con uno stitch.
5. *1v1: perdo un pezzo a ogni morte.* Duello con commento a schermo che cresce di assurdità.
