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
  equipaggiamento. Quasi sempre solo testo ⇒ 🔴 (🟡 se in parte coperto).

---

## Riepilogo

**Totali (232 paragrafi):**

| Stato | Conteggio | % |
|---|---|---|
| 🟢 Verde | 163 | 70,3% |
| 🟡 Giallo | 45 | 19,4% |
| 🔴 Rosso | 24 | 10,3% |

**Percentuale di completamento (headline):** considerando i 🟢 come pieni e i 🟡
come metà, l'indice di completezza è **≈ 80,0%**
( (163 + 45/2) / 232 ).

### Conteggi per TIPO

| Tipo | 🟢 | 🟡 | 🔴 | Tot |
|---|---|---|---|---|
| pianeta/orbita (085–113, escl. 100/110) | 27 | 0 | 0 | 27 |
| atterraggio/superficie (incl. 002/070/076/148) | 16 | 9 | 4 | 29 |
| esito-strategia/combattimento (010–026) | 16 | 1 | 0 | 17 |
| incontro-creatura (intro) | 15 | 21 | 12 | 48 |
| evento-interstellare + esiti | 16 | 3 | 3 | 22 |
| snodo «Incontro di spedizione» | 36 | 0 | 0 | 36 |
| procedurale-vario / rimandi-testuali | 15 | 4 | 34 | 53 |
| **Totale** | **163** | **45** | **24** | **232** |

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
| 001 | evento-interstellare | 🟢 | errore di navigazione: +1 Mese di Tour se il salto e' >=3 esagoni. Automatizzato. |
| 002 | procedurale (atterraggio) | 🟢 | Incidente in discesa: se il navigatore è a bordo → ¶070, altrimenti → ¶148. Automatizzato. |
| 003 | incontro-creatura (snodo) | 🟢 | Codificato: `goto` a ¶054 con nuova creatura (Aracat). Fedele. |
| 004 | incontro-creatura (struttura) | 🟢 | Le due scelte (Fuggi → ¶187 / Combatti → ¶193) sono cliccabili e portano a esiti ora automatizzati. |
| 005 | incontro-creatura (X-Wasp) | 🟢 | Strategia Cattura → cattura facile senza combattimento (override alla scelta strategia). Se si combatte, il X-Wasp non è catturabile (si applica l'uccisione) e morde un personaggio a caso prima di morire: perdita di Resistenza = 1 dado −2 (Ufficiale Medico) −2 (Medkit), contrassegnata come veleno. Caveat: la protezione enviorig/armorig di chi viene morso non è modellata (enviorig non esiste come oggetto) e il contrassegno «non curabile» è tracciato ma non ancora imposto alla cura. |
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
| 027 | incontro-creatura (Folisaur) | 🟡 | Creatura preparata e strategia offerta; lo stordimento da sorpresa e lo «shift = 1 dado» del ramo combattimento non sono applicati. |
| 028 | procedurale (alieni invisibili) | 🟢 | Col neuroscanner → +4 PV; altrimenti → ¶189. Automatizzato. |
| 029 | incontro-creatura (Ivy Five) | 🟢 | Sorpresa→combattimento shift 3 sx codificata; ramo «non sorpreso» con azioni standard. |
| 030 | procedurale (globo) | 🟢 | Pulsante «Esamina» (resolver `intel_check`, investigatore = Intelligenza più alta): con E-cage il globo è acquisito (PV al rientro); senza E-cage si ripiega sull'esito acido (−3 Resistenza all'investigatore, annullati dall'armorig); esito peggiore = morte dell'investigatore (con armorig: −3 Resistenza). Caveat: l'enviorig non è modellato, quindi il suo danneggiamento è inerte. |
| 031 | incontro-creatura (Spiker) | 🟡 | Creatura preparata; l'uccisione automatica da sorpresa e il divieto netgun/stunbomb non sono modellati. |
| 032 | procedurale (sisma) | 🟢 | Scossa sismica: 2 dadi di Punti Danno (1 dado se tutti con armorig). Automatizzato. |
| 033 | incontro-creatura (Florist) | 🟡 | Creatura preparata; il divieto di «Comunica» non è imposto dalla UI. |
| 034 | procedurale (delegazione) | 🔴 | Scelta comunica(¶195)/combatti(¶199)/fuggi(¶204) non gestita. |
| 035 | incontro-creatura (Curder) | 🔴 | Condizione enviorig/armorig→tabella o ¶209, e «2 E-cage» non gestite. |
| 036 | procedurale (scultura) | 🟢 | La scultura è acquisibile come artefatto (pulsante «Raccogli», peso 3) con i PV registrati al rientro sulla Pandora; il flusso «scegli un'altra azione» è ok. |
| 037 | incontro-creatura (Snoup) | 🟡 | Creatura preparata; lo svanire + ricerca con scanner (¶020) o fuga non è automatizzato. |
| 038 | procedurale (vulcano) | 🟢 | Eruzione: −12 Punti Resistenza (−6 da soli robot/strumenti se tutti armorig); rover danneggiato se presente. Automatizzato. |
| 039 | incontro-creatura (Allidon) | 🔴 | «Qualsiasi strategia» con tiro 1d6→tabella poi ¶197/¶205 non gestito. |
| 040 | procedurale (rettiliani) | 🟢 | Rettiliani amichevoli: +5 ore, +PV pari all'Intelligenza del comandante (se presente). Automatizzato. |
| 041 | incontro-creatura (Abomnid) | 🟢 | Sorpresa→combattimento shift 2 sx codificata; il ramo Fuga (¶216) usa il rimando. |
| 042 | procedurale (uovo) | 🟡 | L'uovo è acquisibile come artefatto (PV al rientro); il tiro 1d6 al momento del trasporto (1-2 ok / 3-4 → ¶178 / 5-6 → ¶205) non è ancora gestito. |
| 043 | incontro-creatura (Crusher) | 🔴 | Restrizione armi (solo armorig/specibot/turbolaser), distruzione robot, «2 E-cage» non gestite. |
| 044 | evento-interstellare | 🟢 | sforzo FTL: 2 dadi vs Int Manutenzione -> Mesi di Tour. Automatizzato. |
| 045 | incontro-creatura (Armeetle) | 🟡 | Creatura preparata; inefficacia di stunbomb/reconbot/specibot e fuga «2 ore» non gestite. |
| 046 | evento-interstellare | 🟢 | brillamenti stellari: +1 Mese di Tour. Automatizzato. |
| 047 | evento-interstellare | 🟢 | avaria Processore Fuji: 9 - Int(Scienze/Manut). Automatizzato. |
| 048 | incontro-creatura (Ornifly) | 🟡 | Creatura preparata; ramo «la creatura sfreccia via» (niente combattimento) non forzato. |
| 049 | evento-interstellare | 🟢 | tempesta di asteroidi: 9 - Int(CO/Nav/Manut). Automatizzato. |
| 050 | snodo-di-flusso | 🟡 | Il rientro alla Pandora e il movimento interstellare esistono; il paragrafo come «hub» (Azioni di Bordo 4.5) non è esplicitamente collegato. |

### 051–100 — creature, eventi, atterraggi, snodi

| ¶ | Tipo | Stato | Nota |
|---|---|---|---|
| 051 | incontro-creatura (Paraboid) | 🟡 | Creatura preparata; «qualsiasi strategia → la creatura se ne va» non forzato come esito automatico. |
| 052 | evento-interstellare | 🟢 | una creatura catturata a bordo (a caso) muore, con perdita dei suoi PV. Automatizzato. |
| 053 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶008/004/031/153 — Cliffs / Città Aliena / Flat+clima sahariano / gravità+clima tropicale): salto al ramo giusto o ri-tiro Matrice. |
| 054 | incontro-creatura (Aracat) | 🟢 | Intro «felino»: sorpresa+strategia gestite dal motore; nessun effetto extra oltre lo shift standard di sorpresa. |
| 055 | evento-interstellare | 🟡 | danno cerebrale a un membro a caso: Intelligenza -1 dado e, se Int<=2, perdita di 4 PV e ufficio perso. Caveat: gli altri Valori (Combattimento/Velocita/Porto) non sono memorizzati per personaggio, quindi quel "-1" resta narrativo. |
| 056 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (lava fluente adiacente / Citta Aliena / Heavy Veg / Flat+idrografia): lava fluente = esagono adiacente Solid Lava+Liquid Surface (vicinato 6.7). |
| 057 | incontro-creatura (Eleboid) | 🔴 | «Comunica/Combatti» con danno a tutti i robot poi tabella-strategia non gestito. |
| 058 | evento-interstellare (procedurale) | 🟢 | follia dell'Ufficiale Scienze: Resistenza persa dagli altri + 2 dadi -> dirama a 067/073/144 (effetti applicati). Automatizzato. |
| 059 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶028/039/147 — Città Aliena / Pond o Marsh / Cave+idrografia): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 060 | incontro-creatura (Scorsaur) | 🟡 | Creatura preparata; ramo «Combatti → ¶180» (incornata velenosa) non automatizzato. |
| 061 | evento-interstellare | 🟢 | mercanti rinnegati: 2 dadi vs Int Armi -> +1 Mese o ¶169. Automatizzato. |
| 062 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶030/179/066 — Città Aliena / Light Veg.+gravità / Hill+gravità): salto al ramo giusto o ri-tiro Matrice. |
| 063 | incontro-creatura (Nessie) | 🟡 | Creatura preparata e strategia offerta; il requisito «3 E-cage» per il trasporto non è modellato. |
| 064 | evento-interstellare (deviazione Opoplo) | 🟢 | deviazione verso Opoplo (esagono 14, Mesi di Tour, ¶076). Automatizzato. |
| 065 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Cliffs / Liquid Surface+vegetazione): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 066 | incontro-creatura (nebbia, senza pedina) | 🔴 | Creatura «senza counter» con modificatori espliciti e +4 PV Holographer: non gestita (nessun segnalino in dati). |
| 067 | evento-interstellare (esito) | 🟢 | follia temporanea: +1 Mese di Tour. Automatizzato. |
| 068 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶004/173/181 — Città Aliena / Heavy Veg. / Marsh): salto al ramo giusto o ri-tiro Matrice. |
| 069 | incontro-creatura (Glassman, snodo) | 🟢 | Comunica: 1 dado 1-3→¶213 / 4-6→¶217. Combatti: 1 dado 1-4→¶220 / 5-6→¶217. Azione roll_goto. |
| 070 | procedurale (atterraggio) | 🟢 | 2 dadi vs Int navigatore: ≤Int−2 sicuro; Int−1..Int+1 un robot danneggiato; ≥Int+2 schianto (5 Punti Danno). Automatizzato. |
| 071 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶042/051/043 — Città Aliena / gravità quasi assente / atmosfera velenosa): il motore salta al ramo giusto o ri-tira la Matrice. |
| 072 | incontro-creatura (Unithalo) | 🔴 | Sorpresa shift 1 sx, deviazione a ¶206 e ramo Fuga (rapimento) non gestiti. |
| 073 | evento-interstellare (esito) | 🟢 | cura: 2 dadi vs Int Medico -> guarigione, oppure Ufficiale Scienze in animazione sospesa (Resistenza persa, inutilizzabile). Automatizzato. |
| 074 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶028/009/057 — Città Aliena / Flat+gravità / Cave): salto al ramo giusto o ri-tiro Matrice. |
| 075 | incontro-creatura (Aquan) | 🟡 | Sorpresa+strategia gestite; il ramo «Comunica → dona larva → ¶208» non automatizzato. |
| 076 | atterraggio speciale (Opoplo) | 🔴 | Vincoli speciali (strutture sottoterra 0715/1016, non lasciare l'area finché non esplorate) non gestiti. |
| 077 | incontro-creatura (Garbrist) | 🔴 | Comunica(neuroscanner→¶211 / ¶016) e Combatti(¶215) non gestiti. |
| 078 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶009/009/005 — Città Aliena / Flat+clima tropicale / Marsh-Pond-River+clima): segnaposto convertiti in terreni reali (modello multi-terreno 6.7). |
| 079 | incontro-creatura (Sholf) | 🟢 | Intro «orso»: sola scelta strategia, nessun effetto extra; gestito dal motore. |
| 080 | evento-interstellare (procedurale) | 🟢 | evoluzione di una creatura a bordo -> diramazione 081-084. Automatizzato. |
| 081 | esito (game over) | 🟡 | Testo «il gioco è finito» mostrato; il motore non chiude la partita automaticamente da qui. |
| 082 | esito (game over) | 🟡 | Come ¶081: fine partita non innescata automaticamente. |
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
| 117 | atterraggio (artico) | 🟡 | «+1 LSV» ora applicato; resta la ridefinizione città-aliena→ghiaccio glaciale non automatizzata. |
| 118 | atterraggio (sahariano) | 🟢 | Narrativo puro: schiera ed esplora. |
| 119 | atterraggio (temperato) | 🟡 | «La struttura aliena in 0310 non esiste» non è modellato nell'environ. |
| 120 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶006/181/060 — Città Aliena / Cave+atmosfera / Flat-Hill+gravità+clima): salto al ramo giusto o ri-tiro Matrice. |
| 121 | atterraggio (sahariano) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 122 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 123 | atterraggio (oceano) | 🟡 | Ridefinizioni (strutture inesistenti, città→struttura, immersione 6.7) non gestite. |
| 124 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 125 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 126 | atterraggio (artico) | 🟡 | «+1 LSV» ora applicato; resta la ridefinizione città→ghiaccio glaciale non automatizzata. |
| 127 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 128 | atterraggio (sahariano) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 129 | atterraggio (tropicale) | 🟡 | «Le caverne non esistono» non è modellato nell'environ. |
| 130 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (gravita / Citta Aliena / Liquid Surface / Heavy Veg): esagono sottomarino = Liquid Surface (esplorazione in immersione, 5.x). |
| 131 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 132 | atterraggio (oceano/tropicale) | 🟡 | Ridefinizioni vegetazione sopra/sotto e città/struttura inesistenti non gestite. |
| 133 | atterraggio (sahariano) | 🟡 | «+1 LSV» ora applicato; resta «caverne 1101–1103 inesistenti» non automatizzato. |
| 134 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 135 | atterraggio (artico) | 🟢 | «+1 al LSV» applicato automaticamente all'ingresso dell'area; schiera/esplora ok. |
| 136 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 137 | atterraggio (tropicale) | 🟢 | Narrativo puro: schiera ed esplora. |
| 138 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 139 | atterraggio (artico) | 🟡 | «+1 LSV» ora applicato; restano le ridefinizioni fiumi/paludi→ghiaccio non automatizzate. |
| 140 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶006/003/170 — Città Aliena / Flat+atmosfera / Glacial Ice+gravità): il motore salta al ramo giusto o ri-tira la Matrice. |
| 141 | atterraggio (temperato) | 🟢 | Narrativo puro: schiera ed esplora. |
| 142 | incontro-creatura (Decapus) | 🟡 | Sorpresa+strategia gestite dal motore; nessun effetto extra ⇒ vicino al 🟢, ma lo shift di sorpresa è applicato solo dentro `paragraph_logic` (assente per 142). |
| 143 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Flat+Light Veg+idrografia / Cave+atmosfera): combinazioni base+vegetazione-rada risolte dal modello multi-terreno (6.7). |
| 144 | evento-interstellare (esito) | 🟢 | morte dell'Ufficiale Scienze (PV) + 1 dado per Mesi di Tour (5-6=0); se Int Medico <=6 o assente, reinfezione di un altro membro -> ¶058 (guardia anti-ricorsione). Automatizzato. |
| 145 | incontro-creatura (Erequito) | 🟡 | Creatura preparata; il filtro «solo unità più veloci possono combattere» non è imposto. |
| 146 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (Citta Aliena / Cave / Hill+Light Veg+gravita): combinazioni base+vegetazione-rada risolte dal modello multi-terreno (6.7). |
| 147 | procedurale (vermi-tunnel) | 🟡 | Se sorpresa: ogni personaggio perde 1 dado di Resistenza (−2 con SO, −2 con GSO), poi → ¶212. Caveat: armorig/enviorig per-personaggio approssimati (non modellati come oggetti). |
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
| 159 | incontro-creatura (Mirror Fly) | 🟡 | Creatura preparata; «il carapace respinge il turbolaser» non modellato. |
| 160 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/060/153 — Città Aliena / Flat+veg.+gravità / atmosfera+clima sahariano): il motore salta al ramo giusto o ri-tira la Matrice. |
| 161 | incontro-creatura (insetti, senza pedina) | 🔴 | Gruppo variabile (1d6), +3 a ogni attributo, comunica(¶222)/combatti(¶125): non gestito. |
| 162 | incontro-creatura (Draloid, snodo) | 🟢 | Sorpresa → ¶226. Non sorpresa: se l'Ufficiale rilevamento terrestre (GSO) è assente, 2 dadi vs Int max spedizione (≥ → ¶226). Codificato (effetto-intro). |
| 163 | procedurale (shuttle divorato) | 🔴 | Vincolo temporale «torna allo shuttle prima del controllo» e perdita shuttle→¶050 non gestiti. |
| 164 | incontro-creatura (vetta viva, senza pedina) | 🔴 | Modificatori speciali e tiri comunica/combatti/fuga → ¶214/218/221 non gestiti. |
| 165 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/145/151 — Città Aliena / Light Veg.+gravità / Hill+idrografia): salto al ramo giusto o ri-tiro Matrice. |
| 166 | procedurale (gravità) | 🟡 | Caduta per gravità: 2 dadi di Punti Danno (1 se GSO o Reconbot presente), applicati prima al rover. Resta non modellata la clausola enviorig (danno a Resistenza vs rifornimento). |
| 167 | incontro-creatura (Ironhorn) | 🟡 | Creatura preparata; «1 ora per ispezionare» e inefficacia netgun/stunbomb non gestite. |
| 168 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (stagno usato nel rifornimento / Citta Aliena / Glacial Ice / Flat senza veg+atmosfera): aggiunti i flag di stato pond_supply_used e shuttle_hex_unoccupied. |
| 169 | evento-interstellare (esito) | 🟢 | trattativa del Comandante coi pirati: 2 dadi vs sua Int -> fuga / ¶203 / ¶183. Automatizzato. |
| 170 | incontro-creatura (Monoke, snodo) | 🟢 | Sorpresa: il membro col Valore di Velocità più basso (robot o personaggio) viene divorato. Fuga → ¶226. Codificato (intro + paragraph_logic). |
| 171 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶036/145/147 — Città Aliena / Light Veg.+gravità / Mountain): salto al ramo giusto o ri-tiro Matrice. |
| 172 | incontro (alieno città, snodo) | 🟢 | 1 dado: 1-4 → ¶158, 5-6 → ¶228. Instradamento procedurale a dado. |
| 173 | incontro (fungo, senza pedina) | 🔴 | Check Intelligenza/GSO → ¶219/224 non gestito. |
| 174 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶161/048/167 — Città Aliena / veg.+clima tropicale / Flat senza veg.): il motore salta al ramo giusto o ri-tira la Matrice. |
| 175 | procedurale (arma, WO) | 🟢 | Pulsante «Esamina» (resolver `intel_check`): 2 dadi vs Intelligenza più alta → arma trasportabile dopo 1d6 ore / oggetto banale lasciato / esplosione con 2d6 Punti Danno. |
| 176 | incontro (rete vivente, senza pedina) | 🟡 | Sostanzialmente narrativo «scegli azione»; il +3 PV Holographer non viene assegnato. |
| 177 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶042/007/149 — Città Aliena / Mountain+gravità / veg.+clima tropicale): salto al ramo giusto o ri-tiro Matrice. |
| 178 | procedurale (uovo si schiude) | 🔴 | Tiro 1d6 → ¶142/159/162 non gestito. |
| 179 | incontro-creatura (Glosper) | 🟡 | Creatura preparata; uccisione da sorpresa e ramo Combatti→¶227 non gestiti. |
| 180 | procedurale (incornata) | 🟡 | Personaggio a caso: 2 dadi di Resistenza (−3 Medico, −3 medkit), poi → ¶017; armorig annulla la perdita. Caveat: armorig per-personaggio approssimato; enviorig non modellato. |
| 181 | incontro-creatura (Radrod, snodo) | 🟢 | Comunica: con il Neuroscan → ¶230; altrimenti → ¶016. Codificato (come ¶009). |
| 182 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (shuttle non occupato (spedizione lontana) / Citta Aliena / Mountain-Cliffs+clima artico / atmosfera corrosiva): aggiunti i flag di stato pond_supply_used e shuttle_hex_unoccupied. |
| 183 | procedurale (combattimento pirati) | 🟢 | 1 dado: 1-3 pirati respinti (2 dadi Resistenza +1 Mese); 4-5 → ¶191; 6 → Pandora distrutta, gioco finito. Automatizzato. |
| 184 | snodo «Incontro di spedizione» | 🟢 | Condizioni ora interamente valutate (¶155/042/031/029 — atmosfera+robot / Città Aliena / Hill+clima sahariano / Heavy Veg.): il motore salta al ramo giusto o ri-tira la Matrice. |
| 185 | procedurale (dispositivo alieno) | 🔴 | Tiro 1d6 → ¶161/034 non gestito. |
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
| 203 | procedurale (pirati: tributo) | 🔴 | Cessione robot/strumenti o ¶183 non automatizzata. |
| 204 | procedurale (fuga alieni) | 🟢 | 1 dado: 1 +5 PV; 2-3 rover distrutto →¶195; 4-5 imprigionati 1 Mese, rifornimenti confiscati +5 PV; 6→¶210. Automatizzato. |
| 205 | esito-strategia (modificatore) | 🟡 | «Aggressività auto +2, ritira sulla tabella 8.2»: il motore ha la tabella 8.2 ma non applica questa correzione né il rimando-incontro. |
| 206 | procedurale (combattimento Unithalo) | 🔴 | Combattimento a due round con risultati riletti non automatizzato. |
| 207 | esito (orchidea, senza pedina) | 🟢 | Orchidea raccolta: +3 PV, poi 1 dado (4-6 → ¶033). Automatizzato. |
| 208 | procedurale (forma larvale) | 🔴 | Check GSO/tiro 1d6 → +2 PV o incontro creatura non gestito. |
| 209 | procedurale (infezione germe) | 🟢 | Personaggio a caso: −2 Resistenza subito e −1 a ogni Controllo del Rifornimento (salvo Ufficiale Medico presente), curato al rientro. Automatizzato. |
| 210 | procedurale (teletrasporto) | 🟢 | Teletrasporto allo shuttle: +5 PV (una volta per spedizione). Automatizzato. |
| 211 | esito (Garbrist amichevole) | 🟢 | +4 PV, +2 con l'Holographer. Automatizzato. |
| 212 | procedurale (cattura verme) | 🟢 | Con l'Ufficiale Scienze cattura automatica; altrimenti 2 dadi < Int max spedizione. Automatizzato. |
| 213 | esito (Glassman comunica) | 🟢 | +4 col neuroscanner, +2 con Holographer, +2 con Ufficiale Scienze (cumulativi). Automatizzato. |
| 214 | esito (creatura svanisce) | 🟢 | +3 con Holographer, +2 col neuroscanner. Automatizzato. |
| 215 | procedurale (Garbrist combatte) | 🔴 | Danno a tutti i robot/strumenti, poi combattimento: non gestito. |
| 216 | procedurale (Abomnid insegue) | 🔴 | Esito su rover/armorig o uccisione del più lento non automatizzato. |
| 217 | procedurale (Glassman ostile) | 🟡 | Distrugge un personaggio e un robot a caso, poi combattimento di uccisione (shift impostato per il +3). Caveat: modificatore di Combattimento approssimato come shift. |
| 218 | procedurale (combattimento speciale) | 🔴 | Rilettura risultati col turbolaser o shift 2 sx non automatizzati. |
| 219 | esito (fungo intelligente) | 🟢 | +3 col neuroscanner, +2 con Holographer; 1 dado di ore spese. Automatizzato. |
| 220 | incontro-creatura (Glassman fugge) | 🟡 | La logica «fuga su velocità o combatti» è simile a quella codificata altrove, ma per ¶220 non è in `paragraph_logic`: solo testo. |
| 221 | procedurale (campo psionico) | 🟢 | Campo psionico: 1 dado di ore di incoscienza; Intelligenza di ogni personaggio ridotta permanentemente a 6 (se superiore). Automatizzato. |
| 222 | esito (insetti senzienti) | 🔴 | Check Aggressività con PV variabili e diramazione ¶231/¶225 non gestiti. |
| 223 | procedurale (aeron) | 🟢 | L'aeron afferra un robot a caso (rimosso); se nessun robot, un personaggio a caso perde 2 Resistenza. Automatizzato. |
| 224 | procedurale (veleno fungo) | 🟢 | Personaggio investigatore avvelenato: −3 Resistenza a ogni Controllo del Rifornimento (−2 con Medico o medkit, −1 con entrambi), curato al rientro; armorig annulla. Automatizzato. |
| 225 | procedurale (combattimento gruppo) | 🔴 | Somma Valori di Combattimento e regole speciali risultato «E» non automatizzate. |
| 226 | procedurale (Oraloid) | 🟡 | Effetto applicato: distrugge il rover (o divora un robot). Resta da modellare l'incontro-creatura Oraloid (scelta strategia, netgun senza valore). |
| 227 | procedurale (combattimento Glosper) | 🔴 | Rilettura risultati C/D/E (un personaggio fatto a pezzi) non automatizzata. |
| 228 | procedurale (trappola crollo) | 🟢 | 2 dadi vs Velocità per ogni unità: chi fallisce (robot) è distrutto, (personaggio) perde la differenza in Resistenza; rover distrutto; +5 PV se sopravvive qualcuno. Automatizzato. |
| 229 | esito (monoke amichevole) | 🟡 | Cattura facoltativa e 1 ora: il flusso «scegli azione» è ok ma la cattura/ora non sono automatizzate. |
| 230 | procedurale (radrod) | 🟢 | Studio: 2 dadi (−2 con SO) vs Int max: < → +3 PV e cattura (1 ora); ≥ → neuroscanner+creatura distrutti, un personaggio −2 Resistenza e svenuto (2 dadi di ore). Automatizzato. |
| 231 | procedurale (razza ostile) | 🟡 | Razza locale ostile: a ogni Controllo del Rifornimento, 1 dado (1-2 → spedizione imboscata e distrutta). Resta non agganciato il trigger «ingresso in esagono struttura/città». |
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
