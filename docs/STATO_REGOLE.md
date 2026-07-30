# Stato del regolamento — confronto 1:1 regole ↔ gioco

Aggiornato al **2026-06-16**. Confronto tra le **sezioni/casi del regolamento originale**
(*Voyage of the BSM Pandora*, SPI 1981) e ciò che è effettivamente implementato nel
prototipo Godot.

**Legenda**
- 🟢 **Verde** — regola implementata e fedele.
- 🟡 **Giallo** — implementata in parte o con un bug / scostamento dal regolamento.
- 🔴 **Rosso** — non implementata o errata.

## Riepilogo

| Stato | Conteggio |
|---|---|
| 🟢 Verde | 51 |
| 🟡 Giallo | 1 |
| 🔴 Rosso | 0 |

Nucleo "di sistema" (movimento interstellare → tabella pianeti → atterraggio →
matrice di esplorazione → incontro creatura → combattimento) **solido**.
Coperti in questa tornata: **Resistenza 5 (2.5)**, **Valore Intelligenza (3.3)**,
**Rifornimento (7.0/7.1/7.2/7.3)**, **equipaggiamento d'atmosfera (5.2)**,
**snodi "Incontro di spedizione" (6.5)**, **effetti eventi interstellari (4.2)**,
**artefatti (2.4/2.6/9.1)**, **scoring PV completo (guadagni 9.1 e perdite 9.2:
equipaggiamento danneggiato via registro persistente, Crew Log, mesi oltre Tour)**,
**condizione di vittoria (9.3)**, **danni → Resistenza/Porto (8.8/8.9)** e
**Capacità di Porto per gravità + Rover/piedi con segnalini shuttle/squadra (5.6/5.7/5.8)**.
Chiusi nella tornata del **2026-06-16**: **Carta Effetti del Terreno completa (6.6)**
verificata 1:1 sull'originale (18 terreni, non più 12; nebbia; nota «A» del climbkit;
ingressi proibiti «P»), **costi e modificatori multi-terreno (6.7)** ora sommati su
tutti gli strati dell'esagono come vuole la regola, **azione di studio in spedizione
(6.9)** e riconciliazione di **2.2 / 3.5 / 4.6**, che risultavano 🟡 solo per
documentazione arretrata.

Unico residuo (🟡): **4.4** (flusso inizio/fine dal Pandora Entry Box semplificato —
sezione non presente nella traduzione del regolamento). Fuori scope dichiarato: la
sub-penalità ambigua di 9.2 sui Punti Rifornimento e le condizioni 6.5 che dipendono da
sotto-feature non presenti nei dati environ.

---

## [1.0] Introduzione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 1.0 | Gioco solitario a 232 paragrafi | 🟢 | Struttura a paragrafi presente e funzionante. |

## [2.0] Equipaggiamento di gioco
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 2.1 | Mappa con 8 environ a griglia esagonale | 🟢 | 8 environ reali generati (`environ_maps.json`, `generate_environ`). |
| 2.2 | Carte e tabelle | 🟢 | Tutte le 8 carte originali sono consultabili in gioco dal pulsante «Tabelle» (Eventi Interstellari 4.2, Tabella Pianeti 4.3, Capacità di Porto 5.8, Matrice Esplorazione 6.4, Effetti del Terreno 6.6, Strategia d'Incontro 8.2, Valutazione Creatura 8.3, Risultati Combattimento 8.6) e i loro dati sono implementati. |
| 2.3 | 232 paragrafi | 🟢 | Tutti presenti in `paragrafi_it.json` (it/en). |
| 2.4 | Pezzi: 7 personaggi, 4 bot, 21 strumenti, 39 creature, 5 artefatti | 🟢 | Personaggi/bot/strumenti/creature e i **5 artefatti** (`artifacts.json`: ¶004/006/030/036/042) presenti. |
| 2.5 | Unità + Valore Intelligenza + **Resistenza 5** | 🟢 | `MAX_ENDURANCE = 5` (corretto) e Valore Intelligenza determinato a inizio gioco (3.3). |
| 2.6 | Creature e artefatti da catturare/acquisire | 🟢 | Creature (cattura/uccisione) e artefatti (`acquire_artifact`: pulsante sul paragrafo, PV, arma aliena ¶006 usabile in combattimento). |
| 2.7 | Marcatori per attributi variabili | 🟢 | Attributi pianeta, Tour Time, rifornimenti tracciati. |

## [3.0] Come iniziare
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 3.1 | Scelta Tour 10/20/30 mesi | 🟢 | Implementato nel menu/`start_new_game`. |
| 3.2 | Disposizione iniziale | 🟢 | Stato iniziale impostato. |
| 3.3 | Valore Intelligenza di ogni personaggio (tiro 1 dado) | 🟢 | `_roll_intelligence` a inizio partita (1:6, 2-3:7, 4-5:8, 6:9), fisso e salvato; helper `character_intelligence`/`highest_intelligence`. |
| 3.4 | Vai al ¶201 per iniziare | 🟢 | Si parte in fase interstellare. |
| 3.5 | Scelta casuale di personaggio/bot/oggetto | 🟢 | Automatizzata dove i paragrafi la richiedono (24 usi): `_random_alive_char`, `_damage_random_robot`, `_random_unprotected_char` (esclude i protetti dai rig, 5.2), `_slowest_unit`. |

## [4.0] Pandora e Movimento Interstellare
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 4.0 Proc. | Muovi esagono-per-esagono, costo Tour Time, **2 dadi ≤ esagoni (origine inclusa) → evento** | 🟢 | **Corretto in questa sessione**: gate di occorrenza 4.0 + tiro a 2 dadi. |
| 4.1 | Display Interstellare | 🟢 | Mappa interstellare reale con movimento. |
| 4.2 | Tabella Eventi Interstellari | 🟢 | Tabella corretta (2→080 … 12→064) **e** effetti interni dei paragrafi-evento automatizzati (`_apply_interstellar_event_effect`): ¶001/046/047/049 mesi extra; ¶044/061 controllo Intelligenza con tiro (manuale o auto); ¶052 morte creatura catturata (−PV); ¶055 danno cerebrale (Int −1d6, ufficio perso); ¶058 follia Scienze (perdita Resistenza + ramo 067/073/144); ¶064 deviazione verso Opoplo; ¶080 creatura evoluta (rami 081/082/083/084). Restano narrativi i Valori non memorizzati per personaggio (Combattimento/Velocità/Porto al ¶055) e lo schieramento di superficie del ¶064/¶076. |
| 4.3 | Tabella Pianeti | 🟢 | `enter_orbit` + `get_planet_paragraph`. |
| 4.4 | Inizio/fine dal Pandora Entry Box | 🟡 | Flusso inizio/fine semplificato. |
| 4.5 | Azioni di Bordo al ¶050 (riparazioni/cure/studio creature) | 🟢 | Hub ¶050 (`_onboard_actions`): cura tutti i personaggi e ripara l'equipaggiamento danneggiato non distrutto; lo studio creature (PV) avviene al rientro. |
| 4.6 | Tour Time a zero → Tour superato | 🟢 | `_end_tour` chiude il Tour; i mesi extra degli eventi interstellari (4.2) sono spesi via `_spend_tour_months`. La penalità per i mesi oltre il Tour è applicata in `_end_tour`: **−5 PV per mese** (9.2). |

## [5.0] Preparare una Spedizione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 5.1 | Marcatori sulla Traccia Attributi Pianeta/Environ | 🟢 | `setup_orbit_planet`, `planet_attrs`. |
| 5.2 | Scelta unità + **enviorig/armorig per atmosfera** | 🟢 | Scelta unità OK; equipaggiamento d'atmosfera in `effective_char_stat`: Thin → Porto −1; Poison/None (enviorig) → Peso +4, Velocità −1; Corrosive (armorig) → Peso +4, Porto −1. **Rig per-personaggio** come fonte di verità: `char_wears_enviorig`/`char_wears_armorig`/`char_has_rig` (derivati dall'atmosfera) usati dalle clausole dei paragrafi («se il colpito indossa…», «se tutti…»: 035/147/166/180/216/005/008/197/224/030). |
| 5.3 | Punti Rifornimento sullo shuttle (0–20, peso 1) | 🟢 | `planned_supply` con limite. |
| 5.4 | Esagono di atterraggio (tiro di dado) | 🟢 | `land_on_planet`, `landing_hex`. |
| 5.5 | Paragrafo che descrive l'environ | 🟢 | Mostrato all'atterraggio. |
| 5.6 | Scelta unità a bordo vs in spedizione | 🟢 | Selezione squadra/equipaggiamento in preparazione; pannello **Disposizione** mostra sempre dove sta ogni unità (Pandora · Shuttle · superficie). Sull'environ lo **shuttle resta sul landing hex** (segnalino «S») mentre la squadra si sposta col proprio segnalino. Sulla superficie un'unità può **restare a presidiare lo shuttle** (clic sulla pedina → `shuttle_party`): finché lo shuttle è presidiato l'esagono è «occupato» (es. evita l'innesco continuo del ¶163). |
| 5.7 | Spedizione in Rover o a piedi | 🟢 | La squadra è **o** nel Rover **o** a piedi (un solo box di superficie mostrato); pulsante per scegliere il mezzo (`toggle_vehicle`), segnalino squadra «R»/«P» sulla mappa; il Rover è vietato in gravità opprimente (`rover_available`). |
| 5.8 | Carta Capacità di Porto | 🟢 | Capacità per gravità: **shuttle** (`shuttle_capacity_for`), **rover** (`rover_capacity_for`: 50/40/30/20/—) e **Valore di Porto di personaggi/bot/strumenti** scalato dalla gravità (`port_for_gravity`: ×2/+2/=/−2/½) in `effective_char_stat`, oltre a −1 atmosfera sottile (5.2) e −1 per Resistenza persa (8.8). **Limite di superficie imposto** (5.6): `surface_carried_weight` (solo strumenti + Punti Rifornimento) vs `surface_carry_capacity` (Porto di personaggi **e robot**, o capacità del Rover); il lancio è bloccato in sovraccarico e l'etichetta diventa rossa. *(Non si forza l'assegnazione individuale «chi porta cosa»: scelta di progetto, limiti applicati come totali.)* |

## [6.0] Movimento ed Esplorazione della Spedizione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 6.1 | Esplora / muovi+esplora in una mossa | 🟢 | `move_expedition`, `explore_current_hex`. |
| 6.2 | Marcatore Esplorato | 🟢 | Stato `explored` per esagono. |
| 6.3 | Movimento affrettato | 🟢 | `can_hasty_move`, `hasty_move_to`, costo percorso. |
| 6.4 | Matrice di Esplorazione | 🟢 | `get_exploration_2d6` (1° dado colonna, 2° riga). |
| 6.5 | Paragrafo d'incontro di spedizione (3–4 affermazioni condizionali) | 🟢 | I **36 snodi** sono automatizzati (`expedition_encounters.json`, `_route_expedition_encounter`): terreno/gravità/clima/atmosfera valutati, ri-tiro Matrice se nessuna condizione. |
| 6.6 | Carta Effetti del Terreno | 🟢 | Carta trascritta 1:1 in `terrain.json`: **18 tipi di terreno** (prima 12: mancavano Abisso, Fiume, Stagno, Immersione, Lava fluente, Struttura aliena, comunque usati dalle mappe), Modificatore di Rifornimento per ogni terreno, ore d'ingresso a piedi/rover ed esplorazione. Recepite anche le note della carta: **«P» = ingresso proibito** (lava fluente per tutti; dirupi/caverne/paludi col Rover, bloccati in `cell_entry_prohibited` e nei percorsi), **nota «A» del Climbkit** (montagna 3→2, dirupi 5→3, solo all'ingresso e non col rover né in esplorazione) e **nebbia nell'area** (+1 ora per entrare, +2 per esplorare; `environ_fog`, dichiarata dal paragrafo d'atterraggio ¶136/¶139/¶141). Corretto anche il costo d'esplorazione del ghiaccio (5→3). |
| 6.7 | Terreni multipli / speciali | 🟢 | Modello multi-terreno completo: campo `extra` per gli strati aggiuntivi; usato da snodi, ridefinizioni d'area (Gruppo D) e `_current_terrain_is`. **Ore e Modificatore di Rifornimento sommano TUTTI i terreni dell'esagono** come richiede la regola («Tutto il terreno in un esagono viene considerato»): `_cell_layers` + `cell_enter_cost`/`cell_explore_cost`/`cell_supply_modifier`. Esempio del regolamento (pianura + vegetazione fitta + stagno): ingresso 1+2+0 = 3 ore, esplorazione 2+5+1 = 8, rifornimento +1−2−1 = −2. |
| 6.8 | Spesa di ore di spedizione (Traccia Tempo) | 🟢 | `add_expedition_hours` fa avanzare `supply_track_pos`; al raggiungimento dello «spazio di controllo» della gravità (6/12/16/22/30) scatta un Controllo del Rifornimento (7.2) e la posizione si azzera (loop multiplo). |
| 6.9 | Riparazione/cura/studio in spedizione | 🟢 | `repair_gear` (Botkit/Toolkit) e `heal_wounded` (Uff. Medico/Medkit); **studio** con `can_study`/`study_creature` (pulsante «🔬 Studia»): 2 ore, richiede Uff. Scienze, Uff. Rilevamento, Specibot o Neuroscan, e registra il tipo di creatura sul Registro degli Attributi (9.1) **anche senza ucciderla né catturarla** — un tipo si studia una volta sola. |

## [7.0] Rifornimento della Spedizione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 7.1 | Utenti di rifornimento (singolo/doppio) | 🟢 | `supply_user_total`: personaggio ×2, robot ×1, Rover ×2, strumenti ×1; danneggiati/catturati esclusi. Assunzione: tutti gli strumenti non danneggiati hanno il «simbolo di rifornimento» (flag per-strumento assente nei dati). |
| 7.2 | Controllo rifornimento (dado vs Valore Supporto Vitale) | 🟢 | `resolve_supply_check`: un dado → calc1 = floor(Utenti/dado) max 4; calc2 = floor((LSV + Mod. Rifornimento terreno)/dado) max 4 se la somma > 0. Il Modificatore di Rifornimento è la **somma di tutti i terreni dell'esagono** (6.7, `cell_supply_modifier`). Innescato dalla Traccia Tempo (6.8) in `add_expedition_hours`, spazi per gravità 6/12/16/22/30; loop multiplo per spese grandi. Tiro manuale gestito in `GameScreen._on_roll_dice` (`pending_die_purpose = "supply_check"`). |
| 7.3 | Spesa dei Punti Rifornimento | 🟢 | `_expend_supply`: spende da `expedition_supply`; l'ammanco è pagato in Resistenza (1 Punto = 1 Resistenza) via `_apply_damage` (robot-scudo/ferite/morte 8.8). Vecchio `_consume_supply_for` rimosso. |

## [8.0] Creature, Combattimento e Danni
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 8.1 | Controllo di sorpresa | 🟢 | `surprise_active` (con effetto Scanner). |
| 8.2 | Strategia d'incontro + Tabella | 🟢 | `choose_encounter_strategy` + tabella strategia. |
| 8.3 | Asterisco = istruzione speciale | 🟢 | Le istruzioni speciali (rami-paragrafo) sono ora interamente codificate: tutti i 232 paragrafi automatizzati. |
| 8.4 | Valutazione della creatura | 🟢 | `RATING_TABLE`/`CREATURE_RATING_TABLE` (lookup di 2d6±mod, 12→ritiro) per **tutti** gli attributi, **incluso il combat rating** (`roll_creature_combat_rating`): non più la somma grezza. Verificato sulla Carta 8.4. |
| 8.5 | Sequenza di combattimento | 🟢 | Differenziale = Valore Combattimento spedizione − creatura; 1d6 = riga, colonna dal differenziale (+ spostamenti, segno verificato sulle carte). `best_combat` usa il miglior Valore singolo (la somma di gruppo è caso speciale, ¶225, gestito). |
| 8.6 | Tabella Risultati di Combattimento | 🟢 | Tabella reale 6 righe (dado) × 9 colonne (differenziale) → A-E in `tables.json` (`combat_results.rows`); `GameData.combat_result(diff, die, shift)`. Verificata sulla Carta 8.6. |
| 8.7 | Uccisa/catturata/fuga + Danni | 🟢 | Esiti per lettera distinti Uccidi/Cattura con Punti Danno reali (A=1; B=2/4; C=4/8; D=8 / cattura fallita; E=fuga 8/12), `_combat_damage`. Verificati sulla Carta 8.7. |
| 8.8 | Danni → rimozione Punti Resistenza / riduzione Porto | 🟢 | Ogni Punto Danno toglie 1 Resistenza (robot-scudo 6.9, poi personaggi, morte a 0); inoltre **ogni Resistenza persa riduce di 1 il Valore di Porto** del personaggio in `effective_char_stat` (non sotto zero). L'ammanco di rifornimento (7.3) è pagato in Resistenza. |
| 8.9 | Valore di Porto ridotto / strumento danneggiato | 🟢 | `damaged_gear` per la spedizione + **registro persistente** `gear_damaged_log` per lo scoring (9.2); **riduzione del Porto per perdita di Resistenza** in `effective_char_stat` (8.8). |

## [9.0] Condizioni di Vittoria
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 9.1 | PV guadagnati (attributi creatura, cattura, artefatti, pianeta esplorato) | 🟢 | Tutti i canali: **1 PV per attributo creatura a zero** (`_record_creature_attributes` su uccisione/cattura/studio), cattura riportata viva, artefatti, **1 PV per pianeta esplorato** (`land_on_planet`), e PV da paragrafo. |
| 9.2 | PV persi (personaggio −10, Resistenza −1, bot/rover, tipo strumento, mesi oltre Tour) | 🟢 | Tutti i canali in `_end_tour`: personaggio ucciso −10 (in `_kill_character`), −1 per Resistenza persa dai sopravvissuti, **−1 per robot/rover danneggiato** e **−1 per tipo di strumento danneggiato** a fine gioco (registro persistente `gear_damaged_log`, svuotato dalla riparazione al ¶050), **−5 per riga del Crew Log** (ogni personaggio perso) e −5 per mese oltre il Tour. *(Resta fuori la sub-penalità ambigua «1 PV per Punto Rifornimento speso/non disponibile» della stessa riga: richiederebbe il tracciamento del rifornimento per-tipo.)* |
| 9.3 | Totale finale PV / condizione di vittoria | 🟢 | `_end_tour` totalizza i PV e fissa il **verdetto** in `final_result` (`win`/`lose`): vittoria se i PV ≥ il doppio dei mesi del Tour scelto, altrimenti sconfitta; esito a log. |

---

## Residui noti (tutto il resto è chiuso)

1. **4.4 — Pandora Entry Box** (🟡): il flusso di inizio/fine partita è semplificato
   rispetto alla procedura del box. La sezione **non è presente nella traduzione**
   del regolamento (`regolamento_it.md`), quindi manca il testo di riferimento per
   modellarla fedelmente.
2. **9.2 — sub-penalità sui Punti Rifornimento** (fuori scope dichiarato): la voce
   «1 PV per Punto Rifornimento speso/non disponibile» è ambigua nell'originale e
   richiederebbe il tracciamento del rifornimento per-tipo. Tutte le altre voci di
   9.2 sono applicate.
3. **6.5 — condizioni inerti** (dati): alcune affermazioni degli snodi dipendono da
   sotto-feature non presenti nei dati environ (`_exp_cond_holds` le valuta FALSE per
   prudenza). Non è un bug di logica ma un arricchimento dati.
4. **Assegnazione individuale del carico** (5.8): i limiti di Porto sono applicati
   come totali (shuttle e superficie), non «chi porta cosa». Scelta di progetto.

### Storico delle correzioni maggiori
- ✅ Resistenza 6 → **5** (2.5) · ✅ Valore Intelligenza (3.3) · ✅ Snodi d'incontro
  6.5 (36/36) · ✅ Rifornimento 7.0–7.3 con Traccia Tempo 6.8 · ✅ Rig d'atmosfera
  (5.2) · ✅ Artefatti (2.6/9.1) · ✅ Effetti dei paragrafi-evento (4.2) ·
  ✅ Combattimento verificato sulle carte 8.4/8.6/8.7 · ✅ Scoring completo 9.1/9.2 e
  vittoria 9.3 · ✅ Carta Effetti del Terreno completa e multi-terreno 6.6/6.7 ·
  ✅ Studio in spedizione (6.9).
