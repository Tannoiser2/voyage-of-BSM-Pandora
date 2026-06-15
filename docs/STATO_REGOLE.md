# Stato del regolamento — confronto 1:1 regole ↔ gioco

Aggiornato al **2026-06-15**. Confronto tra le **sezioni/casi del regolamento originale**
(*Voyage of the BSM Pandora*, SPI 1981) e ciò che è effettivamente implementato nel
prototipo Godot.

**Legenda**
- 🟢 **Verde** — regola implementata e fedele.
- 🟡 **Giallo** — implementata in parte o con un bug / scostamento dal regolamento.
- 🔴 **Rosso** — non implementata o errata.

## Riepilogo

| Stato | Conteggio |
|---|---|
| 🟢 Verde | 46 |
| 🟡 Giallo | 6 |
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
Migliorie residue (🟡): arricchimento dati environ (clima + terreni mancanti per
attivare le condizioni 6.5 oggi inerti), modificatori di rifornimento del terreno (6.6)
e dettagli minori (2.2 carte, 3.5 selezione casuale, 4.4/4.6 entry box).

---

## [1.0] Introduzione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 1.0 | Gioco solitario a 232 paragrafi | 🟢 | Struttura a paragrafi presente e funzionante. |

## [2.0] Equipaggiamento di gioco
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 2.1 | Mappa con 8 environ a griglia esagonale | 🟢 | 8 environ reali generati (`environ_maps.json`, `generate_environ`). |
| 2.2 | Carte e tabelle | 🟡 | Presenti: Eventi Interstellari, Matrice Esplorazione, Risultati Combattimento, Valutazione Creatura, Strategia d'Incontro. Mancano/parziali: Capacità di Porto, Effetti del Terreno (modificatori rifornimento). |
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
| 3.5 | Scelta casuale di personaggio/bot/oggetto | 🟡 | La selezione casuale richiesta da molti paragrafi non è automatizzata. |

## [4.0] Pandora e Movimento Interstellare
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 4.0 Proc. | Muovi esagono-per-esagono, costo Tour Time, **2 dadi ≤ esagoni (origine inclusa) → evento** | 🟢 | **Corretto in questa sessione**: gate di occorrenza 4.0 + tiro a 2 dadi. |
| 4.1 | Display Interstellare | 🟢 | Mappa interstellare reale con movimento. |
| 4.2 | Tabella Eventi Interstellari | 🟢 | Tabella corretta (2→080 … 12→064) **e** effetti interni dei paragrafi-evento automatizzati (`_apply_interstellar_event_effect`): ¶001/046/047/049 mesi extra; ¶044/061 controllo Intelligenza con tiro (manuale o auto); ¶052 morte creatura catturata (−PV); ¶055 danno cerebrale (Int −1d6, ufficio perso); ¶058 follia Scienze (perdita Resistenza + ramo 067/073/144); ¶064 deviazione verso Opoplo; ¶080 creatura evoluta (rami 081/082/083/084). Restano narrativi i Valori non memorizzati per personaggio (Combattimento/Velocità/Porto al ¶055) e lo schieramento di superficie del ¶064/¶076. |
| 4.3 | Tabella Pianeti | 🟢 | `enter_orbit` + `get_planet_paragraph`. |
| 4.4 | Inizio/fine dal Pandora Entry Box | 🟡 | Flusso inizio/fine semplificato. |
| 4.5 | Azioni di Bordo al ¶050 (riparazioni/cure/studio creature) | 🟢 | Hub ¶050 (`_onboard_actions`): cura tutti i personaggi e ripara l'equipaggiamento danneggiato non distrutto; lo studio creature (PV) avviene al rientro. |
| 4.6 | Tour Time a zero → Tour superato | 🟡 | `_end_tour` presente; i mesi extra degli eventi interstellari (4.2) sono spesi via `_spend_tour_months`, che chiude il Tour se i mesi si esauriscono. Resta parziale la penalità per i mesi oltre il Tour. |

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
| 5.8 | Carta Capacità di Porto | 🟢 | Capacità per gravità: **shuttle** (`shuttle_capacity_for`), **rover** (`rover_capacity_for`: 50/40/30/20/—) e **Valore di Porto di personaggi/bot/strumenti** scalato dalla gravità (`port_for_gravity`: ×2/+2/=/−2/½) in `effective_char_stat`, oltre a −1 atmosfera sottile (5.2) e −1 per Resistenza persa (8.8). Capacità di superficie mostrata (rover per gravità o somma dei Porti a piedi). *(Non si forza l'assegnazione individuale «chi porta cosa»: scelta di progetto, limiti applicati come totali.)* |

## [6.0] Movimento ed Esplorazione della Spedizione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 6.1 | Esplora / muovi+esplora in una mossa | 🟢 | `move_expedition`, `explore_current_hex`. |
| 6.2 | Marcatore Esplorato | 🟢 | Stato `explored` per esagono. |
| 6.3 | Movimento affrettato | 🟢 | `can_hasty_move`, `hasty_move_to`, costo percorso. |
| 6.4 | Matrice di Esplorazione | 🟢 | `get_exploration_2d6` (1° dado colonna, 2° riga). |
| 6.5 | Paragrafo d'incontro di spedizione (3–4 affermazioni condizionali) | 🟢 | I **36 snodi** sono automatizzati (`expedition_encounters.json`, `_route_expedition_encounter`): terreno/gravità/clima/atmosfera valutati, ri-tiro Matrice se nessuna condizione. |
| 6.6 | Carta Effetti del Terreno | 🟡 | Costi in ore per entrare/esplorare sì; modificatori di rifornimento parziali. |
| 6.7 | Terreni multipli / speciali | 🟢 | Modello multi-terreno completo: campo `extra` per gli strati aggiuntivi; usato da snodi, ridefinizioni d'area (Gruppo D) e `_current_terrain_is`. |
| 6.8 | Spesa di ore di spedizione (Traccia Tempo) | 🟢 | `add_expedition_hours` fa avanzare `supply_track_pos`; al raggiungimento dello «spazio di controllo» della gravità (6/12/16/22/30) scatta un Controllo del Rifornimento (7.2) e la posizione si azzera (loop multiplo). |
| 6.9 | Riparazione/cura/studio in spedizione | 🟡 | `repair_gear`, `heal_wounded` sì; "studio" no. |

## [7.0] Rifornimento della Spedizione
| Caso | Regola | Stato | Nota |
|---|---|:--:|---|
| 7.1 | Utenti di rifornimento (singolo/doppio) | 🟢 | `supply_user_total`: personaggio ×2, robot ×1, Rover ×2, strumenti ×1; danneggiati/catturati esclusi. Assunzione: tutti gli strumenti non danneggiati hanno il «simbolo di rifornimento» (flag per-strumento assente nei dati). |
| 7.2 | Controllo rifornimento (dado vs Valore Supporto Vitale) | 🟢 | `resolve_supply_check`: un dado → calc1 = floor(Utenti/dado) max 4; calc2 = floor((LSV + Mod. Rifornimento terreno)/dado) max 4 se la somma > 0. Innescato dalla Traccia Tempo (6.8) in `add_expedition_hours`, spazi per gravità 6/12/16/22/30; loop multiplo per spese grandi. Tiro manuale gestito in `GameScreen._on_roll_dice` (`pending_die_purpose = "supply_check"`). |
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

## Bug / scostamenti da correggere (priorità)
1. **Resistenza 6 → 5** (2.5): valore errato rispetto al regolamento. *(impatta bilanciamento e PV 9.2)*
2. **Valore Intelligenza personaggi** (3.3): assente; serve a molti eventi/paragrafi.
3. **Snodi "Incontro di spedizione"** (6.5): 36 paragrafi non valutati — serve un piccolo interprete di condizioni terreno/gravità/clima.
4. ~~**Rifornimento 7.0**: supply check (7.2) e utenti singolo/doppio (7.1).~~ ✅ fatto (Traccia Tempo 6.8 → controllo 7.1/7.2/7.3).
5. ~~**Equipaggiamento d'atmosfera** (5.2): enviorig/armorig obbligatori.~~ ✅ fatto (`effective_char_stat`: Thin/Poison/Corrosive).
6. **Artefatti** (2.6/9.1): 5 artefatti e relativi PV.
7. **Effetti interni dei paragrafi-evento interstellari** (4.2).
