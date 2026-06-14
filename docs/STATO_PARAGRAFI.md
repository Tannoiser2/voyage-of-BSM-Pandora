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
  (`interstellar_events`), ma le **meccaniche interne** (mesi di tour spesi,
  uccisioni d'equipaggio, controlli d'Intelligenza, danni cerebrali) **non** sono
  automatizzate: solo testo ⇒ 🔴/🟡.
- **snodo «Incontro di spedizione» (053, 056, …):** tabelle di salto condizionato
  a terreno/gravità/clima/atmosfera. Il motore **non** valuta le condizioni; il
  giocatore deve scegliere a mano il rimando corretto ⇒ 🔴.
- **procedurale-vario:** tiri/condizioni con effetti su Resistenza, PV, ore,
  equipaggiamento. Quasi sempre solo testo ⇒ 🔴 (🟡 se in parte coperto).

---

## Riepilogo

**Totali (232 paragrafi):**

| Stato | Conteggio | % |
|---|---|---|
| 🟢 Verde | 64 | 27,6% |
| 🟡 Giallo | 45 | 19,4% |
| 🔴 Rosso | 123 | 53,0% |

**Percentuale di completamento (headline):** considerando i 🟢 come pieni e i 🟡
come metà, l'indice di completezza è **≈ 37,3%**
( (64 + 45/2) / 232 ).

### Conteggi per TIPO

| Tipo | 🟢 | 🟡 | 🔴 | Tot |
|---|---|---|---|---|
| pianeta/orbita (085–113, escl. 100/110) | 27 | 0 | 0 | 27 |
| atterraggio/superficie (incl. 002/070/076/148) | 12 | 13 | 4 | 29 |
| esito-strategia/combattimento (010–026) | 16 | 1 | 0 | 17 |
| incontro-creatura (intro) | 6 | 22 | 20 | 48 |
| evento-interstellare + esiti | 0 | 2 | 20 | 22 |
| snodo «Incontro di spedizione» | 0 | 0 | 36 | 36 |
| procedurale-vario / rimandi-testuali | 3 | 7 | 43 | 53 |
| **Totale** | **64** | **45** | **123** | **232** |

> Lettura: il cuore «sistemico» del gioco (orbita→pianeta→atterraggio→esplorazione
> con tiro Matrice 6.4, incontro creatura 8.1/8.2/8.4 e combattimento 8.5/8.6) è
> implementato. Manca quasi tutto il **contenuto ramificato** dei singoli
> paragrafi: gli snodi «Incontro di spedizione» (36 tabelle condizionali), gli
> eventi interstellari interni, e le decine di paragrafi procedurali con effetti su
> Resistenza/PV/ore/equipaggiamento.

---

## Tabella 1:1 (paragrafi 001–232)

### 001–050 — preludio, eventi interstellari, esiti-strategia, snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 001 | evento-interstellare | 🔴 | Routing 2d6 ok, ma il «+1 mese di tour se ≥3 esagoni» non è applicato dal motore: solo testo. |
| 002 | procedurale (atterraggio) | 🔴 | Salto condizionato al navigatore (¶070/¶148) non automatizzato; mostrato come testo. |
| 003 | incontro-creatura (snodo) | 🟢 | Codificato: `goto` a ¶054 con nuova creatura (Aracat). Fedele. |
| 004 | incontro-creatura (struttura) | 🔴 | Scelta fuga(¶187)/combatti(¶193) non gestita; nessuna logica codificata. |
| 005 | incontro-creatura (X-Wasp) | 🟡 | Creatura preparata e strategia offerta; il morso velenoso e la perdita di PV su dado non sono applicati. |
| 006 | procedurale (arma) | 🟡 | L'arma aliena è acquisibile (pulsante «Raccogli») con PV al rientro e usabile in combattimento (Cattura/Uccisione 9); il check Intelligenza/2 dadi che ne determina l'usabilità (subito / dopo 5 ore / solo trasportabile) e il rimando all'ufficiale alle armi (¶175) non sono ancora automatizzati. |
| 007 | incontro-creatura (Drada) | 🟢 | Sorpresa→combattimento shift 2 sx codificata; il ramo «non sorpreso» usa le azioni standard. |
| 008 | procedurale (caduta) | 🔴 | Morte/danni casuali con eccezioni (gravità/armorig/climbkit) non gestiti. |
| 009 | incontro-creatura (snodo) | 🔴 | Comunica con check Intelligenza+neuroscanner e PV, o ¶016: nessuna logica codificata. |
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
| 027 | incontro-creatura (Folisaur) | 🟡 | Creatura preparata e strategia offerta; lo stordimento da sorpresa e lo «shift = 1 dado» del ramo combattimento non sono applicati. |
| 028 | procedurale (alieni invisibili) | 🔴 | Check neuroscanner→+4 PV o ¶189 non gestito; solo testo. |
| 029 | incontro-creatura (Ivy Five) | 🟢 | Sorpresa→combattimento shift 3 sx codificata; ramo «non sorpreso» con azioni standard. |
| 030 | procedurale (globo) | 🟡 | Il globo è acquisibile come artefatto (PV al rientro); i tre esiti del check Intelligenza (E-cage / -3 Resistenza+enviorig / morte) e il vincolo «serve una E-cage» non sono ancora automatizzati. |
| 031 | incontro-creatura (Spiker) | 🟡 | Creatura preparata; l'uccisione automatica da sorpresa e il divieto netgun/stunbomb non sono modellati. |
| 032 | procedurale (sisma) | 🔴 | 2 dadi di Punti Danno (1 se tutti armorig) non automatizzati. |
| 033 | incontro-creatura (Florist) | 🟡 | Creatura preparata; il divieto di «Comunica» non è imposto dalla UI. |
| 034 | procedurale (delegazione) | 🔴 | Scelta comunica(¶195)/combatti(¶199)/fuggi(¶204) non gestita. |
| 035 | incontro-creatura (Curder) | 🔴 | Condizione enviorig/armorig→tabella o ¶209, e «2 E-cage» non gestite. |
| 036 | procedurale (scultura) | 🟢 | La scultura è acquisibile come artefatto (pulsante «Raccogli», peso 3) con i PV registrati al rientro sulla Pandora; il flusso «scegli un'altra azione» è ok. |
| 037 | incontro-creatura (Snoup) | 🟡 | Creatura preparata; lo svanire + ricerca con scanner (¶020) o fuga non è automatizzato. |
| 038 | procedurale (vulcano) | 🔴 | Perdita di 12 (o 6) Resistenza e danno al rover non automatizzati. |
| 039 | incontro-creatura (Allidon) | 🔴 | «Qualsiasi strategia» con tiro 1d6→tabella poi ¶197/¶205 non gestito. |
| 040 | procedurale (rettiliani) | 🔴 | PV = Intelligenza CO (+4 Holographer) e divieto esagoni città non automatizzati. |
| 041 | incontro-creatura (Abomnid) | 🟢 | Sorpresa→combattimento shift 2 sx codificata; il ramo Fuga (¶216) usa il rimando. |
| 042 | procedurale (uovo) | 🟡 | L'uovo è acquisibile come artefatto (PV al rientro); il tiro 1d6 al momento del trasporto (1-2 ok / 3-4 → ¶178 / 5-6 → ¶205) non è ancora gestito. |
| 043 | incontro-creatura (Crusher) | 🔴 | Restrizione armi (solo armorig/specibot/turbolaser), distruzione robot, «2 E-cage» non gestite. |
| 044 | evento-interstellare | 🔴 | Check MntO/Intelligenza per mesi di tour spesi non automatizzato. |
| 045 | incontro-creatura (Armeetle) | 🟡 | Creatura preparata; inefficacia di stunbomb/reconbot/specibot e fuga «2 ore» non gestite. |
| 046 | evento-interstellare | 🔴 | «+1 mese di tour extra» non applicato dal motore: solo testo. |
| 047 | evento-interstellare | 🔴 | «9 − Intelligenza (GSO/MntO/GTO)» mesi extra non automatizzato. |
| 048 | incontro-creatura (Ornifly) | 🟡 | Creatura preparata; ramo «la creatura sfreccia via» (niente combattimento) non forzato. |
| 049 | evento-interstellare | 🔴 | «9 − Intelligenza (CO/Nav/MntO)» mesi extra non automatizzato. |
| 050 | snodo-di-flusso | 🟡 | Il rientro alla Pandora e il movimento interstellare esistono; il paragrafo come «hub» (Azioni di Bordo 4.5) non è esplicitamente collegato. |

### 051–100 — creature, eventi, atterraggi, snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 051 | incontro-creatura (Paraboid) | 🟡 | Creatura preparata; «qualsiasi strategia → la creatura se ne va» non forzato come esito automatico. |
| 052 | evento-interstellare | 🔴 | Morte di una creatura a bordo (a caso) non automatizzata. |
| 053 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (dirupo/struttura/clima/gravità → ¶008/004/031/153) non valutata. |
| 054 | incontro-creatura (Aracat) | 🟢 | Intro «felino»: sorpresa+strategia gestite dal motore; nessun effetto extra oltre lo shift standard di sorpresa. |
| 055 | evento-interstellare | 🔴 | Danno cerebrale a un membro (riduzione Valori/PV) non automatizzato. |
| 056 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶038/004/027/151) non valutata. |
| 057 | incontro-creatura (Eleboid) | 🔴 | «Comunica/Combatti» con danno a tutti i robot poi tabella-strategia non gestito. |
| 058 | evento-interstellare (procedurale) | 🔴 | Check Intelligenza GSO, perdita Resistenza e dirama a ¶067/073/144 non gestito. |
| 059 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶028/039/147) non valutata. |
| 060 | incontro-creatura (Scorsaur) | 🟡 | Creatura preparata; ramo «Combatti → ¶180» (incornata velenosa) non automatizzato. |
| 061 | evento-interstellare | 🔴 | Check WO/Intelligenza, +1 mese o ¶169 non automatizzato. |
| 062 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶030/179/066) non valutata. |
| 063 | incontro-creatura (Nessie) | 🟡 | Creatura preparata e strategia offerta; il requisito «3 E-cage» per il trasporto non è modellato. |
| 064 | evento-interstellare (deviazione Opoplo) | 🔴 | Deviazione di rotta verso Opoplo, esagono 0817 e ¶076 non automatizzati. |
| 065 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶030/170/075) non valutata. |
| 066 | incontro-creatura (nebbia, senza pedina) | 🔴 | Creatura «senza counter» con modificatori espliciti e +4 PV Holographer: non gestita (nessun segnalino in dati). |
| 067 | evento-interstellare (esito) | 🔴 | «+1 mese di tour» (follia temporanea) non applicato; solo testo. |
| 068 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶004/173/181) non valutata. |
| 069 | incontro-creatura (Glassman, snodo) | 🔴 | Comunica/Combatti con tiri 1d6 → ¶213/217/220 non gestiti. |
| 070 | procedurale (atterraggio shuttle) | 🔴 | Tre esiti su Intelligenza navigatore (danni/robot/5 Punti Danno) non automatizzati. |
| 071 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶042/051/043) non valutata. |
| 072 | incontro-creatura (Unithalo) | 🔴 | Sorpresa shift 1 sx, deviazione a ¶206 e ramo Fuga (rapimento) non gestiti. |
| 073 | evento-interstellare (esito) | 🔴 | Check MedO/Intelligenza (cura o animazione sospesa) non automatizzato. |
| 074 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶028/009/057) non valutata. |
| 075 | incontro-creatura (Aquan) | 🟡 | Sorpresa+strategia gestite; il ramo «Comunica → dona larva → ¶208» non automatizzato. |
| 076 | atterraggio speciale (Opoplo) | 🔴 | Vincoli speciali (strutture sottoterra 0715/1016, non lasciare l'area finché non esplorate) non gestiti. |
| 077 | incontro-creatura (Garbrist) | 🔴 | Comunica(neuroscanner→¶211 / ¶016) e Combatti(¶215) non gestiti. |
| 078 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶009/009/005) non valutata. |
| 079 | incontro-creatura (Sholf) | 🟢 | Intro «orso»: sola scelta strategia, nessun effetto extra; gestito dal motore. |
| 080 | evento-interstellare (procedurale) | 🔴 | Evoluzione creatura a bordo e diramazione ¶081–084 non gestite. |
| 081 | esito (game over) | 🟡 | Testo «il gioco è finito» mostrato; il motore non chiude la partita automaticamente da qui. |
| 082 | esito (game over) | 🟡 | Come ¶081: fine partita non innescata automaticamente. |
| 083 | evento-interstellare (esito) | 🔴 | Distruzione di 1/3 delle creature a bordo non automatizzata. |
| 084 | evento-interstellare (esito) | 🔴 | Check Combattimento/Intelligenza e uccisioni d'equipaggio non gestiti. |
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
| 100 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶002/006/207/005) non valutata. |

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
| 110 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶028/159/176) non valutata. |
| 111 | pianeta/orbita (Birss 30) | 🟢 | Dati pianeta + atterraggio gestiti. |
| 112 | pianeta/orbita (Mephisto 30) | 🟢 | Idem, da dati. |
| 113 | pianeta/orbita (New Alto 30) | 🟢 | Idem, da dati. |
| 114 | atterraggio (acquatico) | 🟡 | Schiera/esplora ok; il vincolo «tutta l'esplorazione in immersione (6.7)» non è imposto. |
| 115 | atterraggio (artico) | 🟡 | Schiera/esplora ok; «+1 al LSV» va applicato a mano. |
| 116 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora l'esagono di atterraggio. |
| 117 | atterraggio (artico) | 🟡 | «+1 LSV» e ridefinizione città-aliena→ghiaccio non automatizzati. |
| 118 | atterraggio (sahariano) | 🟢 | Narrativo puro: schiera ed esplora. |
| 119 | atterraggio (temperato) | 🟡 | «La struttura aliena in 0310 non esiste» non è modellato nell'environ. |
| 120 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶006/181/060) non valutata. |
| 121 | atterraggio (sahariano) | 🟡 | «+1 LSV» va applicato a mano. |
| 122 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 123 | atterraggio (oceano) | 🟡 | Ridefinizioni (strutture inesistenti, città→struttura, immersione 6.7) non gestite. |
| 124 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 125 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 126 | atterraggio (artico) | 🟡 | «+1 LSV» e ridefinizione città→ghiaccio non automatizzati. |
| 127 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 128 | atterraggio (sahariano) | 🟡 | «+1 LSV» va applicato a mano. |
| 129 | atterraggio (tropicale) | 🟡 | «Le caverne non esistono» non è modellato nell'environ. |
| 130 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶166/042/142/029) non valutata. |
| 131 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 132 | atterraggio (oceano/tropicale) | 🟡 | Ridefinizioni vegetazione sopra/sotto e città/struttura inesistenti non gestite. |
| 133 | atterraggio (sahariano) | 🟡 | «+1 LSV» e «caverne 1101–1103 inesistenti» non automatizzati. |
| 134 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 135 | atterraggio (artico) | 🟡 | «+1 LSV» va applicato a mano. |
| 136 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 137 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 138 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 139 | atterraggio (artico) | 🟡 | «+1 LSV» e ridefinizioni fiumi/paludi→ghiaccio non automatizzati. |
| 140 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶006/003/170) non valutata. |
| 141 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 142 | incontro-creatura (Decapus) | 🟡 | Sorpresa+strategia gestite dal motore; nessun effetto extra ⇒ vicino al 🟢, ma lo shift di sorpresa è applicato solo dentro `paragraph_logic` (assente per 142). |
| 143 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶006/003/162) non valutata. |
| 144 | evento-interstellare (esito) | 🔴 | Mesi di tour, reinfezione e rimando a ¶058 non automatizzati. |
| 145 | incontro-creatura (Erequito) | 🟡 | Creatura preparata; il filtro «solo unità più veloci possono combattere» non è imposto. |
| 146 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶030/045/179) non valutata. |
| 147 | incontro-creatura (Promite, procedurale) | 🔴 | Perdite di Resistenza da sorpresa (con modificatori) e rimando a ¶212 non gestiti. |
| 148 | procedurale (atterraggio) | 🔴 | Due esiti di schianto (5/12 Punti Danno) su check Intelligenza non automatizzati. |
| 149 | incontro-creatura (Bisape) | 🟡 | Sorpresa shift 1 sx (citata nel testo) non applicata; strategia offerta. |
| 150 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶030/045/162) non valutata. |

### 151–200 — creature, esiti speciali e snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 151 | incontro-creatura (Ursamax) | 🟡 | Sorpresa shift 2 sx non applicata automaticamente; strategia offerta. |
| 152 | procedurale (virus dello stagno) | 🔴 | Morte/sedazione con eccezioni MedO/medkit e ore non automatizzate. |
| 153 | incontro-creatura (Bubbler) | 🟡 | Strategia offerta; sorpresa shift 1 sx e «risultato D/E → tutti morti» non applicati. |
| 154 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶040/156/167) non valutata. |
| 155 | procedurale (atmosfera/robot) | 🔴 | Deterioramento robot a ogni controllo rifornimento non automatizzato. |
| 156 | incontro-creatura (Aenon, snodo) | 🔴 | Filtro ambot/turbolaser → fuga o ¶223 non gestito. |
| 157 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶030/072/054/032) non valutata. |
| 158 | esito (alieno amichevole) | 🔴 | +5 PV e bonus CO/neuroscanner/Holographer e divieto incontri successivi non automatizzati. |
| 159 | incontro-creatura (Mirror Fly) | 🟡 | Creatura preparata; «il carapace respinge il turbolaser» non modellato. |
| 160 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶036/060/153) non valutata. |
| 161 | incontro-creatura (insetti, senza pedina) | 🔴 | Gruppo variabile (1d6), +3 a ogni attributo, comunica(¶222)/combatti(¶125): non gestito. |
| 162 | incontro-creatura (Draloid, snodo) | 🔴 | Sorpresa→¶226 e check Intelligenza/GTO non gestiti. |
| 163 | procedurale (shuttle divorato) | 🔴 | Vincolo temporale «torna allo shuttle prima del controllo» e perdita shuttle→¶050 non gestiti. |
| 164 | incontro-creatura (vetta viva, senza pedina) | 🔴 | Modificatori speciali e tiri comunica/combatti/fuga → ¶214/218/221 non gestiti. |
| 165 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶036/145/151) non valutata. |
| 166 | procedurale (gravità) | 🔴 | 2 dadi di Punti Danno (1 con GTO/Reconbot) con regole rover/enviorig non automatizzati. |
| 167 | incontro-creatura (Ironhorn) | 🟡 | Creatura preparata; «1 ora per ispezionare» e inefficacia netgun/stunbomb non gestite. |
| 168 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶152/036/041/066) non valutata. |
| 169 | evento-interstellare (esito) | 🔴 | Trattativa CO con check Intelligenza → ¶203/183 non gestita. |
| 170 | incontro-creatura (snodo) | 🔴 | Sorpresa (divora il più lento), strategia, ramo Fuga→¶226 non gestiti. |
| 171 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶036/145/147) non valutata. |
| 172 | incontro (alieno città, snodo) | 🔴 | Tiro 1d6 → ¶158/228 non gestito. |
| 173 | incontro (fungo, senza pedina) | 🔴 | Check Intelligenza/GSO → ¶219/224 non gestito. |
| 174 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶161/048/167) non valutata. |
| 175 | procedurale (arma, WO) | 🔴 | Tre esiti su check Intelligenza (ore/oggetto/danni) non automatizzati. |
| 176 | incontro (rete vivente, senza pedina) | 🟡 | Sostanzialmente narrativo «scegli azione»; il +3 PV Holographer non viene assegnato. |
| 177 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶042/007/149) non valutata. |
| 178 | procedurale (uovo si schiude) | 🔴 | Tiro 1d6 → ¶142/159/162 non gestito. |
| 179 | incontro-creatura (Glosper) | 🟡 | Creatura preparata; uccisione da sorpresa e ramo Combatti→¶227 non gestiti. |
| 180 | procedurale (incornata) | 🔴 | Perdita Resistenza (2 dadi, modificatori) poi rimando a ¶017 non gestiti. |
| 181 | incontro-creatura (Garbrist, snodo) | 🔴 | Comunica(neuroscanner→¶230 / ¶016) non gestito. |
| 182 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶163/036/041/043) non valutata. |
| 183 | procedurale (combattimento pirati) | 🔴 | Tiro 1d6 con esiti (Resistenza/¶191/game over) non automatizzato. |
| 184 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶155/042/031/029) non valutata. |
| 185 | procedurale (dispositivo alieno) | 🔴 | Tiro 1d6 → ¶161/034 non gestito. |
| 186 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶042/027/051) non valutata. |
| 187 | procedurale (fuga dalla struttura) | 🔴 | Tiro 2 dadi per unità vs Velocità, distruzioni e modificatori non automatizzati. |
| 188 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶034/039/142) non valutata. |
| 189 | procedurale (furto equipaggiamento) | 🔴 | Tiro 1d6 e rimozione casuale robot/strumenti non automatizzati. |
| 190 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶172/037/164) non valutata. |
| 191 | procedurale (esito pirati) | 🔴 | Uccisioni casuali, perdita robot/strumenti e mesi di tour non automatizzati. |
| 192 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶161/037/159) non valutata. |
| 193 | procedurale (combattimento struttura) | 🟡 | Il pezzo di struttura è ora acquisibile come artefatto (¶193, peso 3, PV al rientro — chiave artefatto spostata da ¶004 a ¶193); il combattimento speciale via Intelligenza (solo col turbolaser) e il ramo -10 Resistenza→¶187 restano da automatizzare. |
| 194 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶172/063/069) non valutata. |
| 195 | procedurale (comunicazione alieni) | 🔴 | Tiro 1d6 con modificatori CO/GSO/neuroscanner e PV/¶210 non gestiti. |
| 196 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶161/079/048) non valutata. |
| 197 | procedurale (fungo parassita) | 🔴 | Perdita Resistenza a ogni controllo rifornimento (salvo armorig) non automatizzata. |
| 198 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶040/077/079) non valutata. |
| 199 | procedurale (combattimento alieni) | 🔴 | Tiro 1d6 con perdite equipaggiamento/PV/¶210 non gestiti. |
| 200 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶028/077/035) non valutata. |

### 201–232 — avvio, esiti finali, snodi e chiusura

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 201 | snodo-di-flusso (avvio) | 🟢 | Avvio del viaggio: il motore avvia tour, mappa interstellare e tabella pianeti. Fedele. |
| 202 | snodo «Incontro di spedizione» | 🔴 | Tabella condizionale (¶034/035/057) non valutata. |
| 203 | procedurale (pirati: tributo) | 🔴 | Cessione robot/strumenti o ¶183 non automatizzata. |
| 204 | procedurale (fuga alieni) | 🔴 | Tiro 1d6 con esiti multipli (prigionia/PV/rover/¶195/¶210) non gestiti. |
| 205 | esito-strategia (modificatore) | 🟡 | «Aggressività auto +2, ritira sulla tabella 8.2»: il motore ha la tabella 8.2 ma non applica questa correzione né il rimando-incontro. |
| 206 | procedurale (combattimento Unithalo) | 🔴 | Combattimento a due round con risultati riletti non automatizzato. |
| 207 | incontro (orchidea, senza pedina) | 🔴 | +3 PV se raccolta + tiro 1d6 → ¶033 non gestiti. |
| 208 | procedurale (forma larvale) | 🔴 | Check GSO/tiro 1d6 → +2 PV o incontro creatura non gestito. |
| 209 | procedurale (infezione germe) | 🔴 | -2 Resistenza + perdita a ogni controllo (salvo MedO/medkit) non automatizzata. |
| 210 | procedurale (teletrasporto) | 🔴 | Sparizione equipaggiamento/creature e +5 PV non automatizzati. |
| 211 | esito (Garbrist amichevole) | 🔴 | +4 PV (+2 Holographer) non assegnati automaticamente. |
| 212 | procedurale (cattura verme) | 🔴 | Cattura su GSO/check Intelligenza e blocco PV non gestiti. |
| 213 | esito (Glassman comunica) | 🔴 | PV cumulativi (neuroscanner/Holographer/GSO) non assegnati. |
| 214 | esito (creatura svanisce) | 🔴 | +3 PV Holographer / +2 neuroscanner non assegnati. |
| 215 | procedurale (Garbrist combatte) | 🔴 | Danno a tutti i robot/strumenti, poi combattimento: non gestito. |
| 216 | procedurale (Abomnid insegue) | 🔴 | Esito su rover/armorig o uccisione del più lento non automatizzato. |
| 217 | procedurale (Glassman ostile) | 🔴 | Distruzione personaggio+robot e combattimento con mod +3 non gestiti. |
| 218 | procedurale (combattimento speciale) | 🔴 | Rilettura risultati col turbolaser o shift 2 sx non automatizzati. |
| 219 | esito (fungo intelligente) | 🔴 | +3 PV neuroscanner/+2 Holographer e ore su dado non assegnati. |
| 220 | incontro-creatura (Glassman fugge) | 🟡 | La logica «fuga su velocità o combatti» è simile a quella codificata altrove, ma per ¶220 non è in `paragraph_logic`: solo testo. |
| 221 | procedurale (campo psionico) | 🔴 | Ore su dado e riduzione permanente Intelligenza a 6 non automatizzate. |
| 222 | esito (insetti senzienti) | 🔴 | Check Aggressività con PV variabili e diramazione ¶231/¶225 non gestiti. |
| 223 | procedurale (aeron) | 🔴 | Rapimento robot o -2 Resistenza a un personaggio non automatizzati. |
| 224 | procedurale (veleno fungo) | 🔴 | Perdita Resistenza a ogni controllo (modificata da MedO/medkit/armorig) non gestita. |
| 225 | procedurale (combattimento gruppo) | 🔴 | Somma Valori di Combattimento e regole speciali risultato «E» non automatizzate. |
| 226 | incontro-creatura (Oraloid) | 🟡 | Strategia offerta; distruzione rover/robot e inefficacia netgun non gestite. |
| 227 | procedurale (combattimento Glosper) | 🔴 | Rilettura risultati C/D/E (un personaggio fatto a pezzi) non automatizzata. |
| 228 | procedurale (trappola crollo) | 🔴 | Tiri 2 dadi vs Velocità per unità, distruzioni e +5 PV non automatizzati. |
| 229 | esito (monoke amichevole) | 🟡 | Cattura facoltativa e 1 ora: il flusso «scegli azione» è ok ma la cattura/ora non sono automatizzate. |
| 230 | procedurale (radrod) | 🔴 | Check Intelligenza con +3 PV/cattura o danni e ore non automatizzato. |
| 231 | procedurale (razza ostile) | 🔴 | Tiro 1d6 a ogni esagono città/controllo rifornimento (rischio distruzione) non automatizzato. |
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
