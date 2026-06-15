# Stato dei Paragrafi — confronto 1:1 regolamento ↔ gioco

**Data dell'analisi:** 2026-06-14
**Oggetto:** adattamento digitale Godot del libro-gioco SPI *Voyage of the BSM Pandora* (232 paragrafi).

Questo documento confronta, paragrafo per paragrafo, il testo del regolamento
(`godot/data/paragrafi_it.json`) con ciò che il motore di gioco
(`godot/scripts/GameState.gd` + `GameData.gd` + `GameScreen.gd`) effettivamente
**automatizza**. Le fonti consultate: i 232 testi, la logica codificata
(`paragraph_logic.json`, che copre 003/007/010–026/029/041), le tabelle
(`tables.json`, `interstellar.json`), le creature (`creatures.json`) e le unità
(`units.json`).

## Legenda della classificazione

- 🟢 **Verde** — il gioco lo gestisce correttamente: è narrativo-puro e il motore
  mostra il testo e offre le azioni standard giuste, **oppure** la sua
  logica/ramificazione è interamente codificata e fedele al testo.
- 🟡 **Giallo** — fatto ma con bug o parziale: logica codificata solo in parte; il
  testo è mostrato ma una parte delle meccaniche va applicata a mano; deviazione
  minore dal regolamento.
- 🔴 **Rosso** — non fatto o errato: paragrafo con meccaniche/ramificazioni (tiri,
  condizioni, effetti su Resistenza/PV/ore, salti condizionati) che il motore
  mostra come semplice testo **senza** automatizzarle; oppure dati/mappature
  sbagliate.

### Note metodologiche sui tipi ricorrenti

- **pianeta/orbita (085–113):** mappati interamente da dati (gravità, atmosfera,
  idro, geologia, LSV, tiro d'atterraggio → esagono → paragrafo). `enter_orbit()`
  e `land_on_planet()` li eseguono. → 🟢
- **atterraggio/superficie (114–141, dispari narrativi):** «schiera ed esplora».
  Il motore schiera la squadra e fa esplorare l'esagono. Quando il testo aggiunge
  un effetto numerico non gestito (es. «Aggiungi uno al LSV», ridefinizioni di
  terreno) scende a 🟡, perché l'effetto va applicato a mano.
- **incontro-creatura (intro):** il motore prepara la creatura (`_begin_creature`:
  valutazione 8.4 + sorpresa 8.1) e offre Comunica/Cattura-Uccidi/Fuggi (8.2 via
  `choose_encounter_strategy`). MA gli **effetti speciali della sorpresa** scritti
  nell'intro (uccisioni automatiche, stordimenti, shift particolari) e i **rimandi
  testuali** non codificati non vengono applicati ⇒ in genere 🟡, oppure 🟢 se
  l'intro è pienamente coperto da `paragraph_logic` (007/029/041 per la sola
  sorpresa) o non ha effetti extra.
- **esito-strategia/combattimento (010–026):** **interamente codificati** in
  `paragraph_logic.json` e risolti da `resolve_encounter_outcome`/`_apply_act`
  (fuga, cattura, rilascio con PV, shift di colonna, ore, ecc.). → 🟢 (con
  riserve 🟡 dove la regola cita enviorig/armorig che il motore non modella).
- **evento-interstellare (testo):** il **routing** 2d6→paragrafo è corretto
  (`interstellar_events`) **e** le meccaniche interne sono automatizzate
  (`_apply_interstellar_event_effect`): mesi di tour spesi, uccisioni d'equipaggio,
  controlli d'Intelligenza, danni cerebrali, deviazione Opoplo, evoluzione creatura
  e tutti gli esiti (067/073/083/084/144/169). ⇒ 🟢 (055 🟡: solo l'Intelligenza è
  memorizzata per personaggio).
- **snodo «Incontro di spedizione» (053, 056, …):** tabelle di salto condizionato
  a terreno/gravità/clima/atmosfera. L'interprete valuta gravità, atmosfera,
  idrografia, geologia, vegetazione, **clima** (5.1, derivato dal testo dell'area:
  «Il clima è X») e l'intero set di **terreni per esagono** rimappato e verificato
  dall'utente sulle 8 mappe environ (modello multi-terreno 6.7): Flat 177, Hill 88,
  Heavy Veg. 87, Mountain 40, Light Veg. 37, River 31, Solid Lava 24, Città Aliena 23,
  Liquid Surface 20, Cliffs 16, Marsh 16, Glacial Ice 12, Abyss 11, Cave 4, Pond 3.
  Inoltre, grazie al modello multi-terreno (6.7) e ai tipi River/Abyss/Pond/Marsh
  ora mappati, sono stati convertiti in condizioni
  reali anche i segnaposto di 7 snodi (059/078/110/194 e 143/146/154). I dati di
  terreno delle 8 mappe sono stati rimappati per intero e verificati uno a uno in un
  foglio esagono×terreno (modello multi-terreno completo). Gli esagoni **sottomarini** sono
  modellati come esagoni **Liquid Surface** (esplorazione in immersione), sbloccando
  065/130/188/198/200. La **lava fluente** (056/202) è modellata come esagono
  adiacente Solid Lava+Liquid Surface (colata liquida), via `environ_neighbors`.
  Infine, con due flag di stato (`pond_supply_used` nel Controllo del Rifornimento
  e `shuttle_hex_unoccupied` = spedizione lontana dallo shuttle) si chiudono 168 e
  182. **Tutti i 36 snodi «Incontro di spedizione» sono ora pienamente valutati ⇒ 🟢.**
  Regola **6.7** (un esagono può contenere più terreni): il motore supporta un campo
  `extra` per i terreni aggiuntivi sovrapposti al terreno base; `_current_terrain_is`
  soddisfa sia il base sia gli extra.
- **procedurale-vario:** tiri/condizioni con effetti su Resistenza, PV, ore,
  equipaggiamento. Ora automatizzati da `_apply_paragraph_effect(para)` (danni con
  eccezione armorig, PV condizionali, ore, uccisioni casuali, infezioni ricorrenti,
  furti, trappole, catena pirati, ecc.) e dalle scelte-giocatore a bottoni
  (`paragraph_choices.json` + `resolve_paragraph_choice`). ⇒ 🟢 (🟡 dove resta un
  caveat documentato).

---

## Riepilogo

**Totali (232 paragrafi):**

| Stato | Conteggio | % |
|---|---|---|
| 🟢 Verde | 213 | 91,8% |
| 🟡 Giallo | 19 | 8,2% |
| 🔴 Rosso | 0 | 0,0% |

**Percentuale di completamento (headline):** considerando i 🟢 come pieni e i 🟡
come metà, l'indice di completezza è **≈ 95,9%**
( (213 + 19/2) / 232 ).

### Conteggi per TIPO

| Tipo | 🟢 | 🟡 | 🔴 | Tot |
|---|---|---|---|---|
| pianeta/orbita (085–113, escl. 100/110) | 27 | 0 | 0 | 27 |
| atterraggio/superficie (incl. 002/070/076/148) | 25 | 4 | 0 | 29 |
| esito-strategia/combattimento (010–026) | 16 | 1 | 0 | 17 |
| incontro-creatura (intro) | 33 | 11 | 0 | 44 |
| evento-interstellare + esiti | 17 | 0 | 0 | 17 |
| snodo «Incontro di spedizione» | 36 | 0 | 0 | 36 |
| procedurale-vario / rimandi-testuali | 59 | 3 | 0 | 62 |
| **Totale** | **213** | **19** | **0** | **232** |

> Lettura: **nessun paragrafo è più completamente non gestito** (0 🔴). Il cuore
> sistemico (orbita→pianeta→atterraggio→esplorazione con tiro Matrice 6.4, incontro
> creatura 8.1/8.2/8.4, combattimento 8.5/8.6) e tutto il **contenuto ramificato**
> sono automatizzati: i 36 snodi «Incontro di spedizione», gli eventi interstellari
> interni e i loro esiti, le scelte-giocatore a bottoni, i combattimenti speciali, e
> circa 60 paragrafi procedurali (danni/PV/ore/uccisioni/infezioni/pirati/trappole).
> I 🟡 residui sono casi con un **caveat documentato** (es. enviorig/armorig
> per-personaggio non modellati come oggetti, dettagli di combattimento a più round,
> ridefinizioni di terreno per-area), non funzionalità mancanti.

---

## Tabella 1:1 (paragrafi 001–232)

### 001–050 — preludio, eventi interstellari, esiti-strategia, snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 001 | evento-interstellare | 🟢 | errore di navigazione: +1 Mese di Tour se il salto e' >=3 esagoni. Automatizzato. |
| 002 | procedurale (atterraggio) | 🟢 | Incidente in discesa: se il navigatore è a bordo → ¶070, altrimenti → ¶148. Automatizzato. |
| 003 | incontro-creatura (snodo) | 🟢 | Codificato: `goto` a ¶054 con nuova creatura (Aracat). Fedele. |
| 004 | incontro-creatura (struttura) | 🟢 | Le due scelte (Fuggi → ¶187 / Combatti → ¶193) sono cliccabili e portano a esiti ora automatizzati. |
| 005 | incontro-creatura (X-Wasp) | 🟢 | Strategia Cattura → cattura facile senza combattimento (override alla scelta strategia). Se si combatte, il X-Wasp non è catturabile (si applica l'uccisione) e morde un personaggio a caso prima di morire: perdita di Resistenza = 1 dado −2 (Ufficiale Medico) −2 (Medkit), contrassegnata come veleno. Il morso colpisce solo un personaggio **senza** enviorig né armorig (se tutti protetti, nessun morso) — rig per-personaggio derivato dall'atmosfera (5.2). Caveat residuo: il contrassegno «non curabile» è tracciato ma non ancora imposto alla cura. |
| 006 | procedurale (arma) | 🟢 | Pulsante «Esamina» (check Intelligenza 3.3, resolver `intel_check`): con l'Ufficiale Armi → ¶175; altrimenti 2 dadi vs Intelligenza più alta → barra di energia usabile subito / usabile dopo 5 ore / solo trasportabile (peso 1). L'arma è usabile in combattimento (Cattura/Uccisione 9) solo dopo essere stata compresa. |
| 007 | incontro-creatura (Drada) | 🟢 | Sorpresa→combattimento shift 2 sx codificata; il ramo «non sorpreso» usa le azioni standard. |
| 008 | procedurale (caduta) | 🟢 | A piedi: un'unità a caso precipita. Eccezioni (gravità quasi assente / climbkit / armorig): non distrutta, −1 dado Resistenza (personaggio) o danneggiata (robot). Nel rover: il rover è distrutto. Automatizzato. |
| 009 | incontro-creatura (snodo) | 🟢 | Comunica: con Intelligenza≥6 e Neuroscan → +3 PV (+1 con Holographer), nessuna cattura; altrimenti → ¶016. Risolto alla scelta della strategia, scavalcando la Tabella di Strategia (nuova condizione `has_gear`). Cattura/Fuga usano la tabella standard. |
| 010 | esito-strategia | 🟢 | Interamente codificato (aggr≤4 fuga/combatti; aggr≥5 perdita 12 Resistenza). |
| 011 | esito-strategia | 🟢 | Codificato: cattura con ore = somma modificatori positivi. |
| 012 | esito-strategia | 🟢 | Codificato: la creatura non segue, scegli altra azione. |
| 013 | esito-strategia | 🟢 | Codificato: rami aggr≤5 e aggr≥6 con shift 2 (1 se GSO/specibot). |
| 014 | esito-strategia | 🟢 | Codificato: fuga su velocità, combattimento con shift dx su Intelligenza negativa. |
| 015 | esito-strategia | 🟢 | Codificato: velocità vs min_spd+1; altrimenti elusione, 1 ora. |
| 016 | esito-strategia | 🟢 | Codificato: ristrategia con 1 ora (CO/GSO) o 3 ore. |
| 017 | esito-strategia | 🟢 | Codificato: rami aggressività + shift su Intelligenza +2/+3. |
| 018 | esito-strategia | 🟢 | Codificato: combattimento shift 1 sx, nessuna cattura; altrimenti 2 ore. |
| 019 | esito-strategia | 🟢 | Codificato (intel/aggr_mod→fuga/cattura/combatti); l'ora di allestimento della E-cage è ora addebitata in tutti i rami (`hours:1`). |
| 020 | esito-strategia | 🟢 | Codificato: shift ±2 secondo somma modificatori. |
| 021 | esito-strategia | 🟢 | Codificato: combattimento shift 2 sx, nessuna cattura; altrimenti 3 ore. |
| 022 | esito-strategia | 🟢 | Codificato: intel≥8 rilascio +2 PV e 1 ora; altrimenti uccisione=cattura. |
| 023 | esito-strategia | 🟢 | Codificato: rami aggressività + shift su max(intel,speed mod). |
| 024 | esito-strategia | 🟡 | Codificato shift 1 sx/no-cattura/danni-Resistenza; il duello «singolo personaggio» e il sub-combattimento col resto del gruppo è semplificato. |
| 025 | esito-strategia | 🟢 | Codificato: intel≥8 rilascio +3 PV (+2 Holographer/+2 GSO), 2 ore; altrimenti uccisione=cattura. |
| 026 | esito-strategia | 🟢 | Codificato: aggr≤3 fuga 2 ore; altrimenti combattimento shift max-mod, danni-Resistenza. |
| 027 | incontro-creatura (Folisaur) | 🟢 | Sorpresa → un personaggio a caso è stordito (escluso da `best_combat` per l'incontro); ramo Combatti → spostamento a sinistra di 1 dado (`shift_die_left`). |
| 028 | procedurale (alieni invisibili) | 🟢 | Col neuroscanner → +4 PV; altrimenti → ¶189. Automatizzato. |
| 029 | incontro-creatura (Ivy Five) | 🟢 | Sorpresa→combattimento shift 3 sx codificata; ramo «non sorpreso» con azioni standard. |
| 030 | procedurale (globo) | 🟢 | Pulsante «Esamina» (resolver `intel_check`, investigatore = Intelligenza più alta): con E-cage il globo è acquisito (PV al rientro); senza E-cage si ripiega sull'esito acido (−3 Resistenza all'investigatore, annullati dall'armorig); esito peggiore = morte dell'investigatore (con armorig: −3 Resistenza). Caveat: l'enviorig non è modellato, quindi il suo danneggiamento è inerte. |
| 031 | incontro-creatura (Spiker) | 🟡 | Creatura preparata; l'uccisione automatica da sorpresa e il divieto netgun/stunbomb non sono modellati. |
| 032 | procedurale (sisma) | 🟢 | Scossa sismica: 2 dadi di Punti Danno (1 dado se tutti con armorig). Automatizzato. |
| 033 | incontro-creatura (Florist) | 🟢 | Creatura preparata; la strategia «Comunica» è disabilitata nella UI (comunicazione non ammessa). |
| 034 | scelta (delegazione aliena) | 🟢 | Bottoni di scelta: Comunica → ¶195, Combatti → ¶199, Fuggi → ¶204. UI a scelte. |
| 035 | incontro-creatura (Curder) | 🟢 | Comunica/Combatti: l'incontro si risolve normalmente solo se **tutti** i personaggi indossano un enviorig o un armorig (rig per-personaggio derivato dall'atmosfera, 5.2); altrimenti → ¶209. |
| 036 | procedurale (scultura) | 🟢 | La scultura è acquisibile come artefatto (pulsante «Raccogli», peso 3) con i PV registrati al rientro sulla Pandora; il flusso «scegli un'altra azione» è ok. |
| 037 | incontro-creatura (Snoup) | 🟢 | Col Combatti la creatura svanisce; con lo Scanner si rilocalizza (2 dadi < Int max → ¶020), altrimenti è fuggita. |
| 038 | procedurale (vulcano) | 🟢 | Eruzione: −12 Punti Resistenza (−6 da soli robot/strumenti se tutti armorig); rover danneggiato se presente. Automatizzato. |
| 039 | incontro-creatura (Allidon) | 🟡 | 1 dado: 5-6 → ¶205; 1-4 incontro normale. Caveat: il rimando «poi → ¶197» dopo la risoluzione non è agganciato. |
| 040 | procedurale (rettiliani) | 🟢 | Rettiliani amichevoli: +5 ore, +PV pari all'Intelligenza del comandante (se presente). Automatizzato. |
| 041 | incontro-creatura (Abomnid) | 🟢 | Sorpresa→combattimento shift 2 sx codificata; il ramo Fuga (¶216) usa il rimando. |
| 042 | procedurale (uovo) | 🟢 | Scelte a bottoni: «Lascia stare» o «Riportala» (tiro 1d6: 1-2 acquisito, 3-4 → ¶178, 5-6 → ¶205) via `roll_goto` con campo `acquire`. |
| 043 | incontro-creatura (Crusher) | 🟢 | Un robot a caso è polverizzato all'intro; in combattimento valgono SOLO i Valori di armorig/specibot/turbolaser (`pending_combat_only_sources` in `best_combat`). |
| 044 | evento-interstellare | 🟢 | sforzo FTL: 2 dadi vs Int Manutenzione -> Mesi di Tour. Automatizzato. |
| 045 | incontro-creatura (Armeetle) | 🟢 | Comunica/Combatti → la creatura sparisce nel tunnel (esito `leave`, +2 ore). Caveat residuo: inefficacia di stunbomb/reconbot/specibot non modellata. |
| 046 | evento-interstellare | 🟢 | brillamenti stellari: +1 Mese di Tour. Automatizzato. |
| 047 | evento-interstellare | 🟢 | avaria Processore Fuji: 9 - Int(Scienze/Manut). Automatizzato. |
| 048 | incontro-creatura (Ornifly) | 🟢 | Comunica o Combatti → la creatura sfreccia via (esito `leave`, nessun combattimento); Fuggi normale. |
| 049 | evento-interstellare | 🟢 | tempesta di asteroidi: 9 - Int(CO/Nav/Manut). Automatizzato. |
| 050 | snodo-di-flusso | 🟢 | Hub Azioni di Bordo (4.5): cura tutti i personaggi (Resistenza al massimo) e ripara l'equipaggiamento danneggiato ma non distrutto (`_onboard_actions`); lo studio creature (PV) avviene al rientro. |

### 051–100 — creature, eventi, atterraggi, snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 051 | incontro-creatura (Paraboid) | 🟢 | Qualsiasi strategia → la creatura si allontana (esito `leave`), via paragraph_logic. |
| 052 | evento-interstellare | 🟢 | una creatura catturata a bordo (a caso) muore, con perdita dei suoi PV. Automatizzato. |
| 053 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶008/004/031/153 — Cliffs / Città Aliena / Flat+clima sahariano / gravità+clima tropicale): salto al ramo giusto o ri-tiro Matrice. |
| 054 | incontro-creatura (Aracat) | 🟢 | Intro «felino»: sorpresa+strategia gestite dal motore; nessun effetto extra oltre lo shift standard di sorpresa. |
| 055 | evento-interstellare | 🟢 | Danno cerebrale a un membro a caso: Intelligenza −1 dado e **tutti gli altri Valori −1** (delta permanente per-personaggio `rating_delta`, applicato da `effective_char_stat`/`best_combat`); se Int≤2, −4 PV e ufficio perso. |
| 056 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (lava fluente adiacente / Citta Aliena / Heavy Veg / Flat+idrografia): lava fluente = esagono adiacente Solid Lava+Liquid Surface (vicinato 6.7). |
| 057 | incontro-creatura (Eleboid) | 🟡 | La creatura d'energia folgora e danneggia tutti i robot all'intro, poi incontro normale. Caveat: il danno è applicato all'intro anziché solo su Comunica/Combatti. |
| 058 | evento-interstellare (procedurale) | 🟢 | follia dell'Ufficiale Scienze: Resistenza persa dagli altri + 2 dadi -> dirama a 067/073/144 (effetti applicati). Automatizzato. |
| 059 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶028/039/147 — Città Aliena / Pond o Marsh / Cave+idrografia): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 060 | incontro-creatura (Scorsaur) | 🟢 | Combatti → ¶180 (incornata velenosa), via paragraph_logic; Comunica/Fuggi normali. |
| 061 | evento-interstellare | 🟢 | mercanti rinnegati: 2 dadi vs Int Armi -> +1 Mese o ¶169. Automatizzato. |
| 062 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶030/179/066 — Città Aliena / Light Veg.+gravità / Hill+gravità): salto al ramo giusto o ri-tiro Matrice. |
| 063 | incontro-creatura (Nessie) | 🟡 | Creatura preparata e strategia offerta; il requisito «3 E-cage» per il trasporto non è modellato. |
| 064 | evento-interstellare (deviazione Opoplo) | 🟢 | deviazione verso Opoplo (esagono 14, Mesi di Tour, ¶076). Automatizzato. |
| 065 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Cliffs / Liquid Surface+vegetazione): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 066 | incontro-creatura (nebbia) | 🟢 | Creatura «Vividmist» aggiunta (mod. Int+2/Comb+1/Aggr+3/Vel+3). Sorpresa → combattimento con spostamento di 2 colonne; con l'Holographer +4 PV. Codificato. |
| 067 | evento-interstellare (esito) | 🟢 | follia temporanea: +1 Mese di Tour. Automatizzato. |
| 068 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶004/173/181 — Città Aliena / Heavy Veg. / Marsh): salto al ramo giusto o ri-tiro Matrice. |
| 069 | incontro-creatura (Glassman, snodo) | 🟢 | Comunica: 1 dado 1-3→¶213 / 4-6→¶217. Combatti: 1 dado 1-4→¶220 / 5-6→¶217. Azione roll_goto. |
| 070 | procedurale (atterraggio) | 🟢 | 2 dadi vs Int navigatore: ≤Int−2 sicuro; Int−1..Int+1 un robot danneggiato; ≥Int+2 schianto (5 Punti Danno). Automatizzato. |
| 071 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶042/051/043 — Città Aliena / gravità quasi assente / atmosfera velenosa): il motore salta al ramo giusto o ri-tira la Matrice. |
| 072 | incontro-creatura (Unithalo) | 🟡 | Sorpresa → combattimento con spostamento di 1 colonna; Combatti → ¶206. Caveat: il ramo Fuga (afferra il più lento) e il combattimento a 2 round di ¶206 non sono modellati. |
| 073 | evento-interstellare (esito) | 🟢 | cura: 2 dadi vs Int Medico -> guarigione, oppure Ufficiale Scienze in animazione sospesa (Resistenza persa, inutilizzabile). Automatizzato. |
| 074 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶028/009/057 — Città Aliena / Flat+gravità / Cave): salto al ramo giusto o ri-tiro Matrice. |
| 075 | incontro-creatura (Aquan) | 🟡 | Sorpresa+strategia gestite; il ramo «Comunica → dona larva → ¶208» non automatizzato. |
| 076 | atterraggio speciale (Opoplo) | 🟢 | Clima temperato; il vincolo «non lasciare l'area finché 0715 o 1016 non è esplorato» è imposto (`cannot_leave_until_explored`, blocco al rientro). |
| 077 | incontro-creatura (Garbrist, snodo) | 🟢 | Comunica: col neuroscanner → ¶211, altrimenti → ¶016; Combatti → ¶215. Codificato (paragraph_logic). |
| 078 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶009/009/005 — Città Aliena / Flat+clima tropicale / Marsh-Pond-River+clima): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 079 | incontro-creatura (Sholf) | 🟢 | Intro «orso»: sola scelta strategia, nessun effetto extra; gestito dal motore. |
| 080 | evento-interstellare (procedurale) | 🟢 | evoluzione di una creatura a bordo -> diramazione 081-084. Automatizzato. |
| 081 | esito (game over) | 🟢 | La creatura prende la Pandora: equipaggio morto e fase GAME_OVER impostata automaticamente. |
| 082 | esito (game over) | 🟢 | Come ¶081: la Pandora è distrutta, equipaggio morto e fase GAME_OVER automatica. |
| 083 | evento-interstellare (esito) | 🟢 | la creatura e un terzo delle creature a bordo (a caso) sono distrutte, con perdita PV. Automatizzato. |
| 084 | evento-interstellare (esito) | 🟢 | 2 dadi vs Valore della creatura -> distruzione senza danni oppure uccisioni d'equipaggio. Automatizzato. |
| 085 | pianeta/orbita (Korkran) | 🟢 | Dati pianeta + tiro atterraggio→esagono→paragrafo gestiti dal motore. |
| 086 | pianeta/orbita (Picole) | 🟢 | Idem, da dati. |
| 087 | pianeta/orbita (Suwathe) | 🟢 | Idem, da dati. |
| 088 | pianeta/orbita (Opoplo) | 🟢 | Idem, da dati. |
| 089 | pianeta/orbita (Mezo) | 🟢 | Idem, da dati. |
| 090 | pianeta/orbita (Paleo) | 🟢 | Idem, da dati. |
| 091 | pianeta/orbita (Birss) | 🟢 | Idem, da dati. |
| 092 | pianeta/orbita (Mephisto) | 🟢 | Idem, da dati. |
| 093 | pianeta/orbita (New Alto) | 🟢 | Idem, da dati. |
| 094 | pianeta/orbita (Korkran 20) | 🟢 | Idem, da dati. |
| 095 | pianeta/orbita (Picole 20) | 🟢 | Idem, da dati. |
| 096 | pianeta/orbita (Suwathe 20) | 🟢 | Idem, da dati. |
| 097 | pianeta/orbita (Opoplo 20) | 🟢 | Idem, da dati. |
| 098 | pianeta/orbita (Mezo 20) | 🟢 | Idem, da dati. |
| 099 | pianeta/orbita (Paleo 20) | 🟢 | Idem, da dati. |
| 100 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶002/006/207/005 — atterraggio / Città Aliena / vegetazione+gravità / Heavy Veg.+atmosfera): il motore salta al ramo giusto o ri-tira la Matrice. |

### 101–150 — orbite, atterraggi, snodi e creature di superficie

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 101 | pianeta/orbita (Birss 20) | 🟢 | Dati pianeta + atterraggio gestiti. |
| 102 | pianeta/orbita (Mephisto 20) | 🟢 | Idem, da dati. |
| 103 | pianeta/orbita (New Alto 20) | 🟢 | Idem, da dati. |
| 104 | pianeta/orbita (Korkran 30) | 🟢 | Idem, da dati. |
| 105 | pianeta/orbita (Picole 30) | 🟢 | Idem, da dati. |
| 106 | pianeta/orbita (Suwathe 30) | 🟢 | Idem, da dati. |
| 107 | pianeta/orbita (Opoplo 30) | 🟢 | Idem, da dati. |
| 108 | pianeta/orbita (Mezo 30) | 🟢 | Idem, da dati. |
| 109 | pianeta/orbita (Paleo 30) | 🟢 | Idem, da dati. |
| 110 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶028/159/176 — Città Aliena / Flat-Hill+gravità / Abyss): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 111 | pianeta/orbita (Birss 30) | 🟢 | Dati pianeta + atterraggio gestiti. |
| 112 | pianeta/orbita (Mephisto 30) | 🟢 | Idem, da dati. |
| 113 | pianeta/orbita (New Alto 30) | 🟢 | Idem, da dati. |
| 114 | atterraggio (acquatico) | 🟡 | Schiera/esplora ok; il vincolo «tutta l'esplorazione in immersione (6.7)» non è imposto. |
| 115 | atterraggio (artico) | 🟢 | «+1 al Valore di Supporto Vitale» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 116 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora l'esagono di atterraggio. |
| 117 | atterraggio (artico) | 🟢 | «+1 LSV» e clima artico; tutti gli esagoni di città aliena rideterminati a ghiaccio glaciale al deploy (`_redef_base`). |
| 118 | atterraggio (sahariano) | 🟢 | Narrativo puro: schiera ed esplora. |
| 119 | atterraggio (temperato) | 🟡 | «La struttura aliena in 0310 non esiste» non è modellato nell'environ. |
| 120 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶006/181/060 — Città Aliena / Cave+atmosfera / Flat-Hill+gravità+clima): salto al ramo giusto o ri-tiro Matrice. |
| 121 | atterraggio (sahariano) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 122 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 123 | atterraggio (oceano) | 🟡 | Ridefinizioni (strutture inesistenti, città→struttura, immersione 6.7) non gestite. |
| 124 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 125 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 126 | atterraggio (artico) | 🟢 | «+1 LSV» e clima artico; città aliana → ghiaccio glaciale al deploy, eccetto l'esagono 1012. |
| 127 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 128 | atterraggio (sahariano) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 129 | atterraggio (tropicale) | 🟢 | Clima tropicale; «le caverne non esistono» applicato (rimozione dello strato Cave dall'environ). |
| 130 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (gravita / Citta Aliena / Liquid Surface / Heavy Veg): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 131 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 132 | atterraggio (oceano/tropicale) | 🟡 | Ridefinizioni vegetazione sopra/sotto e città/struttura inesistenti non gestite. |
| 133 | atterraggio (sahariano) | 🟢 | «+1 LSV» e clima sahariano; le caverne negli esagoni 1101/1102/1103 sono rimosse al deploy. |
| 134 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 135 | atterraggio (artico) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 136 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 137 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 138 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 139 | atterraggio (artico) | 🟢 | «+1 LSV» e clima artico; tutti i fiumi → ghiaccio (base+extra) e le paludi → ghiaccio glaciale al deploy. |
| 140 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶006/003/170 — Città Aliena / Flat+atmosfera / Glacial Ice+gravità): il motore salta al ramo giusto o ri-tira la Matrice. |
| 141 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 142 | incontro-creatura (Decapus) | 🟡 | Sorpresa+strategia gestite dal motore; nessun effetto extra ⇒ vicino al 🟢, ma lo shift di sorpresa è applicato solo dentro `paragraph_logic` (assente per 142). |
| 143 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Flat+Light Veg+idrografia / Cave+atmosfera): combinazioni base+vegetazione-rada risolte dal modello multi-terreno (6.7). |
| 144 | evento-interstellare (esito) | 🟢 | morte dell'Ufficiale Scienze (PV) + 1 dado per Mesi di Tour (5-6=0); se Int Medico <=6 o assente, reinfezione di un altro membro -> ¶058 (guardia anti-ricorsione). Automatizzato. |
| 145 | incontro-creatura (Erequito) | 🟢 | Solo i personaggi/robot con Velocità maggiore della creatura possono ingaggiare il combattimento (`pending_combat_speed_filter`). |
| 146 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Cave / Hill+Light Veg+gravita): combinazioni base+vegetazione-rada risolte dal modello multi-terreno (6.7). |
| 147 | procedurale (vermi-tunnel) | 🟢 | Se sorpresa: ogni personaggio **senza armorig** perde 1 dado di Resistenza (l'enviorig sottrae 1 ed è danneggiato; −2 con SO, −2 con GSO, cumulativi), poi → ¶212. Rig per-personaggio (5.2). |
| 148 | procedurale (atterraggio) | 🟢 | 2 dadi vs Int max a bordo: < Int → 5 Punti Danno; ≥ Int → 12 Punti Danno. Automatizzato. |
| 149 | incontro-creatura (Bisape) | 🟡 | Sorpresa shift 1 sx (citata nel testo) non applicata; strategia offerta. |
| 150 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶030/045/162 — Città Aliena / Cave+gravità / Solid Lava): salto al ramo giusto o ri-tiro Matrice. |

### 151–200 — creature, esiti speciali e snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 151 | incontro-creatura (Ursamax) | 🟡 | Sorpresa shift 2 sx non applicata automaticamente; strategia offerta. |
| 152 | procedurale (virus dello stagno) | 🟢 | Virus: un personaggio a caso muore, salvo medkit + Ufficiale Medico presenti (e la vittima non è il Medico). Automatizzato. |
| 153 | incontro-creatura (Bubbler) | 🟡 | Strategia offerta; sorpresa shift 1 sx e «risultato D/E → tutti morti» non applicati. |
| 154 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Flat+Light Veg+atmosfera / Flat+atmosfera): combinazioni base+vegetazione-rada risolte dal modello multi-terreno (6.7). |
| 155 | procedurale (atmosfera/robot) | 🟡 | Atmosfera velenosa/corrosiva: i robot si deteriorano a ogni Controllo del Rifornimento (gravità 1/3/6 secondo atmosfera e MntO). Modellato come danneggiamento di un robot per controllo (la Resistenza dei robot non è tracciata). |
| 156 | incontro-creatura (Aenon, snodo) | 🟢 | Comunicazione/Combattimento: con Ambot o Turbolaser la creatura fugge (scegli altra azione); altrimenti → ¶223. Codificato. |
| 157 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶030/072/054/032 — Città Aliena / Glacial Ice / Light Veg.+atmosfera / geologia attiva): salto al ramo giusto o ri-tiro Matrice. |
| 158 | esito (alieno amichevole) | 🟢 | Ultimo superstite telepate: +5 PV, +2 per ciascuno tra comandante, neuroscanner e Holographer presenti. Automatizzato. |
| 159 | incontro-creatura (Mirror Fly) | 🟢 | Il carapace riflette il turbolaser: i suoi Valori sono esclusi dal combattimento (`pending_combat_exclude_sources`). |
| 160 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/060/153 — Città Aliena / Flat+veg.+gravità / atmosfera+clima sahariano): il motore salta al ramo giusto o ri-tira la Matrice. |
| 161 | scelta (insetti bipedi) | 🟢 | Bottoni di scelta: Comunica → ¶222, Combatti → ¶125 (fuga impossibile). UI a scelte. |
| 162 | incontro-creatura (Draloid, snodo) | 🟢 | Sorpresa → ¶226. Non sorpresa: se l'Ufficiale rilevamento terrestre (GSO) è assente, 2 dadi vs Int max spedizione (≥ → ¶226). Codificato (effetto-intro). |
| 163 | procedurale (shuttle divorato) | 🟢 | Flag `shuttle_devour_pending`: tornando allo shuttle prima del prossimo Controllo del Rifornimento gli insetti sono respinti; altrimenti lo shuttle è divorato e i personaggi rientrano sulla Pandora → ¶050. |
| 164 | scelta (vetta viva) | 🟢 | Bottoni con tiro: Comunica (1d6 1-4→¶214/5-6→¶221), Combatti (1d6 1-2→¶218/3-4→¶221/5-6 svanisce), Fuga → ¶221. UI a scelte. |
| 165 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/145/151 — Città Aliena / Light Veg.+gravità / Hill+idrografia): salto al ramo giusto o ri-tiro Matrice. |
| 166 | procedurale (gravità) | 🟢 | Caduta per gravità: 2 dadi di Punti Danno (1 se GSO o Reconbot), il rover assorbe per primo. Coi personaggi in enviorig tutti i danni vanno presi come Resistenza (enviorig danneggiati); altrimenti distribuzione normale (scudo robot/Resistenza). |
| 167 | incontro-creatura (Ironhorn) | 🟢 | 1 ora d'ispezione (automatica); netgun e stunbomb esclusi dal combattimento contro questa creatura. |
| 168 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (stagno usato nel rifornimento / Citta Aliena / Glacial Ice / Flat senza veg+atmosfera): aggiunti i flag di stato pond_supply_used e shuttle_hex_unoccupied. |
| 169 | evento-interstellare (esito) | 🟢 | trattativa del Comandante coi pirati: 2 dadi vs sua Int -> fuga / ¶203 / ¶183. Automatizzato. |
| 170 | incontro-creatura (Monoke, snodo) | 🟢 | Sorpresa: il membro col Valore di Velocità più basso (robot o personaggio) viene divorato. Fuga → ¶226. Codificato (intro + paragraph_logic). |
| 171 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/145/147 — Città Aliena / Light Veg.+gravità / Mountain): salto al ramo giusto o ri-tiro Matrice. |
| 172 | incontro (alieno città, snodo) | 🟢 | 1 dado: 1-4 → ¶158, 5-6 → ¶228. Instradamento procedurale a dado. |
| 173 | scelta (fungo) | 🟢 | Bottoni: Investiga (con SO → ¶219; altrimenti 2 dadi vs Int max → ¶219/¶224) o Lascia stare. UI a scelte. |
| 174 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶161/048/167 — Città Aliena / veg.+clima tropicale / Flat senza veg.): il motore salta al ramo giusto o ri-tira la Matrice. |
| 175 | procedurale (arma, WO) | 🟢 | Pulsante «Esamina» (resolver `intel_check`): 2 dadi vs Intelligenza più alta → arma trasportabile dopo 1d6 ore / oggetto banale lasciato / esplosione con 2d6 Punti Danno. |
| 176 | incontro (rete vivente, senza pedina) | 🟢 | Non catturabile/innocua; con l'Holographer si guadagnano 3 PV (automatico). |
| 177 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶042/007/149 — Città Aliena / Mountain+gravità / veg.+clima tropicale): salto al ramo giusto o ri-tiro Matrice. |
| 178 | procedurale (uovo si schiude) | 🟢 | 1 dado automatico: 1-2 → ¶142, 3-4 → ¶159, 5-6 → ¶162. Instradamento a dado. |
| 179 | incontro-creatura (Glosper) | 🟡 | Creatura preparata; uccisione da sorpresa e ramo Combatti→¶227 non gestiti. |
| 180 | procedurale (incornata) | 🟢 | Personaggio a caso: con armorig nessuna perdita; altrimenti 2 dadi di Resistenza (−3 Medico, −3 medkit, −2 enviorig poi danneggiato), poi → ¶017. Rig per-personaggio (5.2). |
| 181 | incontro-creatura (Radrod, snodo) | 🟢 | Comunica: con il Neuroscan → ¶230; altrimenti → ¶016. Codificato (come ¶009). |
| 182 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (shuttle non occupato (spedizione lontana) / Citta Aliena / Mountain-Cliffs+clima artico / atmosfera corrosiva): aggiunti i flag di stato pond_supply_used e shuttle_hex_unoccupied. |
| 183 | procedurale (combattimento pirati) | 🟢 | 1 dado: 1-3 pirati respinti (2 dadi Resistenza +1 Mese); 4-5 → ¶191; 6 → Pandora distrutta, gioco finito. Automatizzato. |
| 184 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶155/042/031/029 — atmosfera+robot / Città Aliena / Hill+clima sahariano / Heavy Veg.): il motore salta al ramo giusto o ri-tira la Matrice. |
| 185 | procedurale (dispositivo alieno) | 🟢 | 1 dado automatico: 1-3 → ¶161, 4-6 → ¶034. Instradamento a dado. |
| 186 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶042/027/051 — Città Aliena / Heavy Veg.+atmosfera / gravità): il motore salta al ramo giusto o ri-tira la Matrice. |
| 187 | procedurale (fuga dalla struttura) | 🟢 | Pulsante «Subisci i raggi»: per ogni personaggio e robot 2 dadi vs Velocità → distruzione se superata; col rover Velocità minima 8; −2 con turbolaser, −2 con scanner, −2 per chi indossa l'armorig. |
| 188 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (citta aliena non esplorata / Marsh+atmosfera / Liquid Surface): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 189 | procedurale (furto equipaggiamento) | 🟢 | Alieni invisibili: 1 dado di oggetti sottratti (robot per primi, poi strumenti; mai rover/armorig/enviorig). Automatizzato. |
| 190 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶172/037/164 — Città Aliena / Heavy Veg. / Mountain+atmosfera): salto al ramo giusto o ri-tiro Matrice. |
| 191 | procedurale (esito pirati) | 🟡 | 1 dado di personaggi uccisi + Mesi di Tour di riparazioni (−2 se MntO vivo) automatizzati. La perdita «uno per tipo con Valore di Combattimento di uccisione» è approssimata (Turbolaser/Netgun/Stunbomb). |
| 192 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶161/037/159 — Città Aliena / Heavy Veg.+gravità / Mountain-Cliffs+atmosfera): salto al ramo giusto o ri-tiro Matrice. |
| 193 | procedurale (combattimento struttura) | 🟢 | Pulsante «Affronta la struttura»: col turbolaser combattimento via Intelligenza (solo uccisione) → struttura distrutta e pezzo recuperato (artefatto ¶193, peso 3, PV al rientro); senza turbolaser −10 Punti Resistenza e fuga obbligata a ¶187. Caveat: la colonna-Intelligenza della Tabella Combattimento è modellata in modo approssimato. |
| 194 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶172/063/069 — Città Aliena / Liquid Surface / River+clima tropicale): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 195 | procedurale (comunicazione alieni) | 🟢 | 1 dado (−1 per CO/SO/neuroscan): ≤1 +7 PV; 2-4 armi dissolte +6 PV; 5-6 → ¶210. Automatizzato. |
| 196 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶161/079/048 — Città Aliena / Glacial Ice+gravità / veg.+clima temperato): il motore salta al ramo giusto o ri-tira la Matrice. |
| 197 | procedurale (fungo parassita) | 🟢 | Personaggio a caso infettato: −1 Resistenza a ogni Controllo del Rifornimento fino al rientro (curato sulla Pandora); l'armorig previene l'infezione. Automatizzato. |
| 198 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Liquid Surface / vegetazione+atmosfera): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 199 | procedurale (esito pirati) | 🟢 | 1 dado: 1→¶195; 2-3 armi+rifornimenti dissolti +5 PV; 4-5 equipaggiamento (tranne armorig/enviorig)+rifornimenti dissolti +5 PV; 6→¶210. Automatizzato. |
| 200 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Liquid Surface+Cliffs-o-Abyss / Light Veg+atmosfera): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |

### 201–232 — avvio, esiti finali, snodi e chiusura

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 201 | snodo-di-flusso (avvio) | 🟢 | Avvio del viaggio: il motore avvia tour, mappa interstellare e tabella pianeti. Fedele. |
| 202 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Flat+Light Veg+gravita / lava fluente adiacente+clima sahariano): lava fluente = esagono adiacente Solid Lava+Liquid Surface (vicinato 6.7). |
| 203 | procedurale (pirati: tributo) | 🟢 | Scelta: cedi un robot/strumento di ogni tipo (i pirati se ne vanno) oppure rifiuta → ¶183. UI a scelte. |
| 204 | procedurale (fuga alieni) | 🟢 | 1 dado: 1 +5 PV; 2-3 rover distrutto →¶195; 4-5 imprigionati 1 Mese, rifornimenti confiscati +5 PV; 6→¶210. Automatizzato. |
| 205 | esito-strategia (modificatore) | 🟢 | Aggressività della creatura +2: ri-tiro sulla Tabella di Strategia (8.2) con la strategia già scelta → paragrafo di destinazione. |
| 206 | procedurale (combattimento Unithalo) | 🟢 | Combattimento in 2 round: al 1° i risultati sono riletti (A nessun effetto; B −3 Resistenza, se muore +3 al rating; C un divorato +3; D/E due divorati +5), poi 2° round coi risultati normali sul differenziale ricalcolato (`pending_two_round`). |
| 207 | esito (orchidea, senza pedina) | 🟢 | Orchidea raccolta: +3 PV, poi 1 dado (4-6 → ¶033). Automatizzato. |
| 208 | incontro-creatura (Reeler) | 🟢 | Con l'Ufficiale Scienze la larva è riportata in salvo (+2 PV); altrimenti 1 dado: 1-3 muore, 4-6 si trasforma e si combatte. Codificato (intro). |
| 209 | procedurale (infezione germe) | 🟢 | Personaggio a caso: −2 Resistenza subito e −1 a ogni Controllo del Rifornimento (salvo Ufficiale Medico presente), curato al rientro. Automatizzato. |
| 210 | procedurale (teletrasporto) | 🟢 | Teletrasporto allo shuttle: +5 PV (una volta per spedizione). Automatizzato. |
| 211 | esito (Garbrist amichevole) | 🟢 | +4 PV, +2 con l'Holographer. Automatizzato. |
| 212 | procedurale (cattura verme) | 🟢 | Con l'Ufficiale Scienze cattura automatica; altrimenti 2 dadi < Int max spedizione. Automatizzato. |
| 213 | esito (Glassman comunica) | 🟢 | +4 col neuroscanner, +2 con Holographer, +2 con Ufficiale Scienze (cumulativi). Automatizzato. |
| 214 | esito (creatura svanisce) | 🟢 | +3 con Holographer, +2 col neuroscanner. Automatizzato. |
| 215 | procedurale (campo mentale Garbrist) | 🟢 | Il campo mentale danneggia tutti i robot/strumenti (non armorig/enviorig/rover), poi si conduce il combattimento normale. Automatizzato. |
| 216 | procedurale (Abomnid insegue) | 🟢 | Col rover o con **tutti** i personaggi in armorig si combatte; altrimenti (a piedi) il personaggio più lento senza armorig viene ucciso e la creatura fugge. Rig per-personaggio (5.2). |
| 217 | procedurale (Glassman ostile) | 🟢 | Distrugge un personaggio e un robot a caso, poi combattimento di sola uccisione con la Valutazione del Glassman rideterminata col modificatore +3 (8.4), non più approssimata come spostamento. |
| 218 | procedurale (combattimento Glosper) | 🟢 | Combattimento di uccisione: col turbolaser i risultati B/C/D contano come A (turbolaser distrutto); senza, spostamento di 2 colonne a favore. Hook remap nel motore sui codici reali A-E (Tabella 8.6 verificata). |
| 219 | esito (fungo intelligente) | 🟢 | +3 col neuroscanner, +2 con Holographer; 1 dado di ore spese. Automatizzato. |
| 220 | incontro-creatura (Glassman fugge) | 🟢 | Se la Velocità del Glassman ≥ Velocità massima della squadra fugge, altrimenti si combatte (paragraph_logic, Valori calcolati). |
| 221 | procedurale (campo psionico) | 🟢 | Campo psionico: 1 dado di ore di incoscienza; Intelligenza di ogni personaggio ridotta permanentemente a 6 (se superiore). Automatizzato. |
| 222 | esito (gruppo creature) | 🟢 | Valore di Aggressività (tiro): ≤4 → +4 PV e ¶231; 5-8 → +PV (Int comandante o 4, +1 neuroscan, +1 Holographer); ≥9 → ¶225. Automatizzato. |
| 223 | procedurale (aeron) | 🟢 | L'aeron afferra un robot a caso (rimosso); se nessun robot, un personaggio a caso perde 2 Resistenza. Automatizzato. |
| 224 | procedurale (veleno fungo) | 🟢 | Personaggio investigatore avvelenato: −3 Resistenza a ogni Controllo del Rifornimento (−2 con Medico o medkit, −1 con entrambi), curato al rientro; armorig annulla. Automatizzato. |
| 225 | procedurale (combattimento gruppo) | 🟢 | Combattimento col **valore combinato** del gruppo (somma di rating 8.4) risolto proceduralmente: solo uccisione, danni come Resistenza, risultato «E» = 12 danni; se la spedizione sopravvive +5 PV → ¶231. Caveat: la dimensione del gruppo è assunta (3) perché non presente nei dati. |
| 226 | procedurale (Oraloid) | 🟡 | Effetto applicato: distrugge il rover (o divora un robot). Resta da modellare l'incontro-creatura Oraloid (scelta strategia, netgun senza valore). |
| 227 | procedurale (combattimento speciale) | 🟢 | Sui risultati C/D/E un personaggio a caso è fatto a pezzi prima di applicare il risultato. Hook kill_on nel motore di combattimento sui codici reali A-E (Tabella 8.6 verificata). |
| 228 | procedurale (trappola crollo) | 🟢 | 2 dadi vs Velocità per ogni unità: chi fallisce (robot) è distrutto, (personaggio) perde la differenza in Resistenza; rover distrutto; +5 PV se sopravvive qualcuno. Automatizzato. |
| 229 | esito (monoke amichevole) | 🟢 | Si spende 1 ora (automatico); la cattura resta facoltativa (a discrezione del giocatore, come da regola). |
| 230 | procedurale (radrod) | 🟢 | Studio: 2 dadi (−2 con SO) vs Int max: < → +3 PV e cattura (1 ora); ≥ → neuroscanner+creatura distrutti, un personaggio −2 Resistenza e svenuto (2 dadi di ore). Automatizzato. |
| 231 | procedurale (razza ostile) | 🟢 | Razza locale ostile: a ogni Controllo del Rifornimento **e all'ingresso in un esagono di città aliena** si tira 1 dado (1-2 → spedizione imboscata e distrutta), via `_hostile_ambush`. |
| 232 | snodo-di-flusso (fine viaggio) | 🟢 | Attracco e calcolo PV finali: il motore mostra ¶232 a fine tour e produce il riepilogo PV (9.0/9.2). Fedele. |

---

## Prossimi passi consigliati (per massimo impatto)

L'impatto maggiore si ottiene chiudendo, nell'ordine, questi lotti:

1. **Snodi «Incontro di spedizione» (36 paragrafi: 053, 056, 059, 062, 065, 068,
   071, 074, 078, 100, 110, 120, 130, 140, 143, 146, 150, 154, 157, 160, 165, 168,
   171, 174, 177, 182, 184, 186, 188, 190, 192, 194, 196, 198, 200, 202).**
   Sono tabelle di salto deterministiche su attributi già noti al motore (terreno
   dell'esagono, gravità/atmosfera/clima del pianeta, stato d'immersione). Un
   piccolo interprete di condizioni (sulla falsariga di `paragraph_logic`)
   risolverebbe **36 paragrafi** in un colpo solo e collegherebbe correttamente la
   Matrice di Esplorazione 6.4 agli incontri reali. **Priorità massima.**

2. **Eventi interstellari interni (001, 044, 046, 047, 049, 052, 055, 058, 061, 064,
   067, 073, 080–084, 144, 169, 183, 191, 203).** Estendere il sistema eventi (già
   instradato 2d6→paragrafo) con gli effetti: mesi di tour spesi, check
   d'Intelligenza degli ufficiali, uccisioni/danni d'equipaggio, game over. Sblocca
   ~18–20 paragrafi e rende il viaggio interstellare realmente conseguente.

3. **Effetti di atterraggio mancanti (114, 115, 117, 119, 121, 123, 126, 128, 129,
   132, 133, 135, 139).** Applicare «+1 LSV», le ridefinizioni di terreno e il
   vincolo d'immersione (6.7). Sono piccoli aggiustamenti che portano 13 paragrafi
   da 🟡 a 🟢.

4. **Effetti speciali della sorpresa nelle intro-creatura (027, 031, 147, 149, 151,
   153, 170, 179, 182, ecc.) e assegnazione PV degli esiti «amichevoli» (158, 176,
   211, 213, 214, 219).** Estendere `paragraph_logic`/`_begin_creature` per
   applicare shift di sorpresa, uccisioni automatiche e i PV da comunicazione.

5. **Paragrafi di combattimento speciale (193, 206, 217, 218, 225, 227)** e i grandi
   procedurali a tiro singolo (069, 164, 172, 173, 178, 185, 195, 199, 204):
   richiedono mini-script dedicati ma completano l'esperienza di superficie.

> Suggerimento implementativo: i lotti 1 e 2 condividono lo stesso pattern
> «condizione → effetto/salto». Generalizzare l'interprete di `paragraph_logic`
> per accettare anche condizioni d'ambiente (terreno/gravità/atmosfera/clima) ed
> effetti procedurali (mesi, Resistenza, PV, ore, uccisioni) coprirebbe da solo la
> maggioranza dei 129 paragrafi rossi.
