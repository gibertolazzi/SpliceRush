# 0001 — Smembramento progressivo e arti come mazze

Data: 2026-11-12 · Stato: implementato sul branch `feat/smembramento-arti-mazza`, da provare in gioco

## Contesto

I personaggi sono modelli 3D interi (una pelle unica su scheletro Mixamo). I pezzi a terra
erano cubi astratti e perdere un arto non produceva nulla di raccoglibile. La richiesta: i
brawler devono sgretolarsi, lasciare a terra braccia e gambe riconoscibili, e chi le raccoglie
deve usarle per menare.

## Decisione

1. **Arti veri dal modello intero.** `LimbMeshLibrary` legge i pesi delle ossa una volta per
   modello, tiene i triangoli di ogni arto (braccia, gambe, testa), li cuoce in posa di riposo
   e ne fa mesh rigide da un solo draw call. Sul corpo l'arto si nasconde collassando le ossa;
   al suo posto resta un incastro da giocattolo (niente sangue, regola 6).
2. **Il corpo si sgretola con la vita.** Scendendo sotto il 66% e il 33% di HP salta un arto
   (prima un braccio, poi una gamba), una volta per vita. Al KO esplodono altri due arti e la
   mazza che si aveva in mano. Al rientro il corpo ricresce intero.
3. **Arto raccolto = mazza o innesto.** Se sei intero lo impugni: più portata, più danno,
   contraccolpo enorme, 5–6 colpi e poi si rompe. Se ti manca quell'arto te lo riattacchi: un
   arto altrui resta del colore del proprietario (corpo-patchwork) e conta come pezzo rubato.
4. **Il tuo arto appena perso è di tutti.** Per 2,5 s non puoi riprenderlo: gli altri hanno la
   precedenza. L'Abominio non perde arti finché non viene abbattuto.
5. **Pezzi speciali a terra realistici.** Motosega su un braccio, gamba-razzo a strisce, testa
   con visore, nuclei come oggetti. I comuni giacciono sul pavimento, i rari levitano nel
   raggio (la rarità si legge da forma e bagliore).

Tutto è deciso dal server (`server/match_server.gd`); i numeri stanno in
`shared/balance_config.gd`, gruppo "Limbs & Clubs". Nessun effetto sul negozio: niente pay-to-win.

## Scostamenti dal GDD e da AGENTS.md

- GDD: "se muori perdi un pezzo". Ora al KO perdi i pezzi speciali come prima, ma braccia e
  gambe ricrescono al rientro.
- Camera: da −32° ravvicinata a circa −50° più alta (key art, AGENTS.md sezione 4). I tre
  valori sono in `shared/default_balance.tres` (`camera_pitch_deg`, `camera_distance`, `camera_z_bias`).
- Palette arena: pavimento in pietra rosata, cielo azzurro, casse colorate.

## Misure (simulazione headless, 3 partite da 90 s, 12 bot)

| | Senza arti | Con arti |
| --- | --- | --- |
| KO per partita | 79–83 | 84–89 |
| Attivazioni Abominio | 10–14 | 11–15 |
| Arti staccati | 0 | 355–389 |
| Colpi di mazza | 0 | 540–584 |
| Pezzi a terra (massimo) | 12–16 | 29–34 |

Export web: `index.pck` 10,5 MB (7,9 MB gzip). La build gira nel browser e gli arti estratti
si vedono anche in WebGL. FPS su telefono e nel browser interno di TikTok: non misurati.

## Aperto

- Ritmo: circa 4 arti al secondo in tutta l'arena. Da giudicare giocando; si regola con
  `limb_break_hp_ratios`, `ko_limb_burst_count`, `max_limb_drops`.
- Testa che rotola al KO e lancio dell'arto come proiettile: non fatti.
