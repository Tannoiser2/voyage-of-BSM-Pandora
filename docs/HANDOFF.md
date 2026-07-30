# Handoff — riprendere il lavoro (Voyage of the BSM Pandora)

**Ultimo aggiornamento:** 2026-06-16 · **Branch:** `claude/game-ui-logging-consolidation-k2qko3` (PR #36)

Documento per ripartire in una nuova sessione. Riassume **dove siamo**, **come
funziona il codice** e **lo stato finale** (100%: 0 🟡, 0 🔴).

---

## 1. Stato attuale

Adattamento digitale Godot del libro-gioco SPI (232 paragrafi). Vedi
`docs/STATO_PARAGRAFI.md` (tabella 1:1) e `docs/STATO_REGOLE.md` (per sezione).

| Stato | Conteggio | Indice di completezza |
|---|---|---|
| 🟢 Verde | 232 | |
| 🟡 Giallo | 0 | **100%** |
| 🔴 Rosso | **0** | (da 36,0% a inizio sessione) |

**Tutti i 232 paragrafi sono pienamente automatizzati e fedeli al regolamento (0 🟡, 0 🔴): indice 100%.**

**Regole di sistema (2026-06-16): 51 🟢 · 1 🟡 · 0 🔴.** L'unico residuo è **4.4**
(Pandora Entry Box, sezione non tradotta nel regolamento). Vedi `STATO_REGOLE.md` §
«Residui noti» per il quadro completo (incluse le voci fuori scope dichiarate).

---

## 2. Come lavorare (setup operativo)

- **Repo:** `/home/user/voyage-of-BSM-Pandora`, codice di gioco in `godot/`.
- **Godot headless:** `/tmp/Godot_v4.4.1-stable_linux.x86_64` (potrebbe non esserci
  in un container nuovo: scaricarlo o usare quello disponibile in `/tmp`).
- **Smoke test (pattern usato in tutta la sessione):** creare un `godot/test_smoke.gd`
  (estende Node, `_ready()` che chiama le funzioni e stampa PASS/FAIL, poi
  `get_tree().quit()`), una `godot/test_smoke.tscn` che lo carica, lanciare
  `Godot --headless --path godot res://test_smoke.tscn`, poi **rimuovere** i due file.
- **Dati JSON pretty-printed:** per `environ_maps.json` usare `json.dump(..., indent=0)`
  (round-trip identico); per `expedition_encounters.json` `indent=2`.
- **Commit:** messaggi chiari; ogni commit finisce con la riga
  `https://claude.ai/code/session_...`. **Push** sul branch di lavoro corrente. NON pushare su altri branch.
- **Doc:** dopo ogni batch, aggiornare `docs/STATO_PARAGRAFI.md` (riga del paragrafo,
  conteggi riepilogo, indice, tabella per-tipo, **Totale**). Le % usano la **virgola**.

---

## 3. Architettura: dove sta cosa (file e funzioni chiave)

Tutto il motore è in `godot/scripts/GameState.gd` (+ `GameData.gd`, `GameScreen.gd`).

### Diario «Cosa succede» — narrazione al centro (v0.10.0)
La finestra centrale è il «cuore dell'azione»; il `log_display` a destra (Registro
di Bordo) è la memoria storica. Due canali in `GameState`:
- **`encounter_trail`** (narrazione visibile) e **`encounter_formulas`** (matematica,
  sezione collassabile). Mostrati da `GameScreen._on_paragraph_request` nel box
  «Cosa succede».
- **Auto-mirror:** `add_log(msg)` rispecchia automaticamente la riga in
  `encounter_trail` quando `_narration_active()` (fasi interstellare/orbita/
  spedizione/paragrafo). Così TUTTE le conseguenze d'azione appaiono al centro senza
  toccare le ~235 chiamate. Guardia `_suppress_trail_mirror` per le formule.
- **Helper:** `_narrate(msg)` (= add_log, marcatore d'intento), `_narrate_formula(msg)`
  (riga collassabile, esclusa dalla narrazione), `_narrate_check(question, yes, conseguenza)`
  (controlli espliciti «c'è X? ▸ Sì/No → conseguenza»).
- **Reset** del diario a ogni nuova azione: `_reset_action_diary()` in
  `move_pandora_to` (salto), `return_to_pandora` (rientro), più i reset di spedizione
  (`reset_expedition_state`, mossa/esplorazione).
- **Eventi 4.2:** gli effetti girano DOPO il render del paragrafo →
  `_refresh_paragraph_view()` in `resolve_interstellar_event`/`resolve_event_die`
  aggiorna il centro (e `_on_paragraph_request` non rigioca il suono sul refresh dello
  stesso paragrafo).

### Terreno: Carta 6.6 + regola 6.7 (multi-strato)
- Dati in `data/terrain.json`: **18 terreni** trascritti dalla carta originale
  (`effects` con `enter_foot`/`enter_rover`/`explore`/`supply` + flag `prohibited`,
  `rover_prohibited`, `explore_prohibited`), `class_map` (classe campionata → terreno
  reale) e `terrain_it`.
- **6.7:** un esagono ha `terrain` (base) + `extra` (strati). Ore e Modificatore di
  Rifornimento **sommano tutti gli strati**: `_cell_layers(cell)` +
  `cell_enter_cost` / `cell_explore_cost` / `cell_supply_modifier`. I terreni-
  sovrapposizione hanno 0 ore d'ingresso («–» sulla carta), il che rende la somma
  coerente coi dati (es. base «Light Vegetation» + extra «Flat»).
- **Proibizioni «P»:** `cell_entry_prohibited` blocca lava fluente (tutti) e
  dirupi/caverne/paludi col Rover; rispettata anche da `can_move_expedition`,
  `can_hasty_move` e dal Dijkstra del movimento affrettato.
- **Climbkit** (nota A): solo ingresso a piedi, montagna→2 / dirupi→3
  (`CLIMBKIT_ENTER`); **non** riduce l'esplorazione.
- **Nebbia:** `environ_fog` (+1 ingresso, +2 esplorazione), impostata in
  `generate_environ_at` da `GameData.paragraph_has_fog(paragrafo d'atterraggio)`.
  Serializzata.

### Studio in spedizione (6.9)
`can_study()` / `study_creature()`: 2 ore, richiede GSO/SO/Specibot/Neuroscan, registra
il tipo di creatura sul Registro degli Attributi (9.1) anche senza uccisione o cattura
(un tipo una volta sola). UI: pulsante «🔬 Studia» nella sezione Azioni.

### Export Web (GitHub Pages)
`godot/export_presets.cfg` ha `include_filter="*.json,*.md"`: i dati (`data/*.json`) e
i documenti (`CHANGELOG.md`) letti via `FileAccess` vanno inclusi esplicitamente, altrimenti
nel build Web risultano vuoti (changelog/tabelle). Le immagini (charts/asset) sono risorse e
si esportano da sole.

### Snodi «Incontro di spedizione» 6.5 (36/36 🟢)
- Dati: `data/expedition_encounters.json` (regole `cond`/`goto`).
- Interprete: `_exp_cond_holds(cond)` in GameState (terreno/gravità/atmo/idro/geologia/
  vegetazione/clima + `lava_in_area`, `unexplored_alien_city_in_area`,
  `shuttle_hex_unoccupied`, `pond_supply_used`).
- **Terreno multi-strato (6.7):** ogni esagono in `environ_maps.json` ha `terrain`
  (base) + `extra` (lista). `_current_terrain_is(real)` controlla base **e** extra.
  Mapping in `terrain.json` → `class_map`. Clima: `GameData.paragraph_climate(num)`.

### Eventi interstellari (4.x)
- `resolve_interstellar_event` → `_apply_interstellar_event_effect(para)` (match per
  paragrafo): `_event_001/044/.../080` + esiti `_event_067/073/144/169` + `_science_madness`.

### Effetti procedurali per-paragrafo (il sistema più usato)
- `_apply_paragraph_effect(para) -> int` in GameState, chiamato da `show_paragraph`
  prima del display. Ritorna un paragrafo di redirect (>0) o 0; applica gli effetti
  numerici **una sola volta per spedizione** (guardia `_landing_fx_applied`).
- Helper: `_apply_damage`, `gain_vp`/`lose_vp`, `add_expedition_hours`,
  `_kill_character`/`_kill_unit`, `_random_alive_char`, `_slowest_unit`,
  `_damage_random_robot`, `_roll_damage_armorig`, `_infect(key, amt)`.
- **Infezioni:** `infected_chars` = `[{key, amt}]`, applicate in `resolve_supply_check`,
  curate in `return_to_pandora`. Anche `robot_decay` (¶155) e `hostile_race` (¶231).

### Scelte-giocatore (UI a bottoni)
- Dati: `data/paragraph_choices.json` (override con `act`: `goto` / `roll_goto` /
  `investigate_173` / `give_tribute_203` / `none`).
- `GameData.get_paragraph_choices(num)` (override o estrazione dai rimandi ¶NNN).
- `GameState.resolve_paragraph_choice(act)` + segnale `choices_resolved`.
- `GameScreen._build_choices` / `_on_choice_act`.

### Incontri-creatura
- Creature: `data/creatures.json` (`{intel, combat, aggression, speed, img, para, vp}`).
  `creature_for_paragraph(para)` le mappa; `_begin_creature` prepara sorpresa (8.1).
- **Intro di sorpresa:** `_apply_creature_intro(para)` (162/170/066/072/057/208/043/039…).
- **Esiti di strategia:** `data/paragraph_logic.json` (`cond`/`act`), risolti da
  `resolve_encounter_outcome` → `_apply_act` (act: goto, **roll_goto**, flee, leave,
  capture, release, combat/restrategy).
- **Combattimento 8.5/8.6:** `resolve_combat(mode, player_combat)`. Hook speciali:
  `pending_combat_shift`, `pending_combat_remap` (+`_destroy`), `pending_combat_kill_on`,
  `pending_no_capture`, `pending_kill_as_capture`.

### Routing a dado (paragrafi non-creatura)
- `_paragraph_dice_route(para) -> int` (172/178/185).

---

## 4. Lavoro svolto (dai 55 🟡 iniziali a 0 — 100%)

Tutti i gruppi A–F dell'handoff originale sono chiusi. Riepilogo per gruppo:

### A. enviorig/armorig per-personaggio — **FATTO (2026-06-15)** ✅
Paragrafi 035, 147, 166, 180, 216 → 🟢 (043 resta 🟡, vedi sotto); fix anche in
005, 008, 197, 224 e nel globo ¶030.
- **Modello scelto (fedele e a basso rischio):** lo stato dei rig è **derivato
  dall'atmosfera** (regola 5.2), uniforme per personaggio: enviorig in atmosfera
  `None`/`Poison`, armorig in `Corrosive`. Niente nuovo stato serializzato né UI.
- **Helper (fonte di verità)** in `GameState`: `char_wears_enviorig(k)`,
  `char_wears_armorig(k)`, `char_has_rig(k)`, `all_exploring_chars_have_rig()`,
  `all_exploring_chars_wear_armorig()`, `_random_unprotected_char()`. Sostituiti i
  `_gear_has("Armorig")` delle clausole di **protezione** con i check per-personaggio
  (lasciato `_gear_has` dove l'armorig è *strumento/arma*: ¶199, combat).
- Fix collaterale: `effective_char_stat` ora applica i modificatori enviorig anche
  in atmosfera `None` (prima solo `Poison`).
- **¶043 → 🟢 (2026-06-15):** la restrizione delle fonti di combattimento è ora
  modellata in `best_combat` con tre hook — `pending_combat_only_sources` (lista
  chiusa, ¶043: solo armorig/specibot/turbolaser), `pending_combat_exclude_sources`
  (esclusioni, ¶159 turbolaser, ¶167 netgun/stunbomb) e `pending_combat_speed_filter`
  (¶145: solo unità più veloci della creatura). Helper `_combat_source_allowed`.

### B. intro-creatura (effetti sorpresa) (8)
Paragrafi: 031, 057, 075, 142, 149, 151, 153, 179.
- Aggiungere/precisare gli effetti-intro in `_apply_creature_intro` (e
  `paragraph_logic` dove serve). Leggere il testo di ciascuno e codificare l'effetto
  di sorpresa specifico. 057: il danno ai robot va legato a Comunica/Combatti, non
  all'intro.

### C. combattimento (round/valore combinato) — **in gran parte FATTO (2026-06-15)**
Paragrafi: 024, 027, 048, 055, 072, 191, 206, 217, 225.
- **206 → 🟢:** combattimento a 2 round (`pending_two_round`/`combat_round`): 1° round
  con risultati riletti (A nessun effetto; B −3 Res., se muore +3 rating; C un divorato
  +3; D/E due divorati +5), poi 2° round normale sul differenziale ricalcolato. ¶072
  Combatti → ¶206.
- **027 → 🟢:** sorpresa stordisce un personaggio (escluso da `best_combat`); Combatti →
  `shift_die_left` (1 dado a sinistra).
- **048 → 🟢:** Comunica/Combatti → la creatura sfreccia via (`leave`).
- **217 → 🟢:** Glassman rideterminato col modificatore +3 (8.4), non più approssimato
  come spostamento; solo uccisione.
- **225 → 🟢 (2026-06-15):** combattimento col valore combinato del gruppo risolto
  proceduralmente (somma di 3 rating 8.4; solo uccisione; danni come Resistenza;
  «E» = 12; sopravvivenza → +5 PV → ¶231). Gruppo assunto di 3 (non nei dati).
- **055 → 🟢 (2026-06-15):** «tutti i Valori −1» modellato con un delta permanente
  per-personaggio `crew[k]["rating_delta"]`, applicato da `effective_char_stat` e
  `best_combat` (oltre a Intelligenza −1d6). Sistema riusabile per futuri ¶ che
  modificano i Valori.
- **Residui:** **024** (duello «singolo personaggio» multi-stadio) e **191** restano
  approssimati ma ragionevoli.

### D. ridefinizioni terreno / vincoli d'area — **FATTO (2026-06-15)** ✅
Paragrafi 076, 117, 126, 129, 133, 139 → 🟢 (114 resta 🟡: esplorazione in immersione).
- `generate_environ_at(landing_real, redef_para)` applica le ridefinizioni al deploy via
  `_apply_landing_terrain_redef(para)` con gli helper `_redef_base` (terreno base, con
  eccezioni di esagono reale), `_redef_remove_extra` (rimuove uno strato extra) e
  `_redef_anywhere` (base + extra): 117/126 città aliena→ghiaccio, 129/133 caverne
  inesistenti, 139 fiumi/paludi→ghiaccio.
- ¶076: vincolo «non lasciare l'area finché 0715 o 1016 esplorato» imposto via
  `cannot_leave_until_explored` + `can_leave_environ()` (blocco in `return_to_pandora`).
- **Residuo 🟡:** ¶114 «tutta l'esplorazione in immersione (6.7)» non imposto come
  vincolo esplicito (l'environ è comunque Liquid Surface).

### E. timing — **FATTO (2026-06-15)** ✅
- **163 → 🟢:** flag `shuttle_devour_pending` impostato al ¶163; al prossimo
  Controllo del Rifornimento, se la spedizione è allo shuttle (`expedition_pos ==
  landing_hex`) gli insetti sono respinti, altrimenti lo shuttle è divorato e i
  personaggi rientrano sulla Pandora → ¶050. Si azzera anche tornando allo shuttle
  (`move_expedition`). Serializzato.

### F. altro/minore — **in gran parte FATTO (2026-06-15)**
- **Fatti → 🟢:** 033 (Comunica disabilitato nella UI), 045 (Comunica/Combatti → fuga
  +2 ore), 051 (qualsiasi strategia → fuga), 060 (Combatti → ¶180), 081/082 (game
  over automatico: equipaggio morto + fase GAME_OVER), 176 (Holographer → +3 PV),
  220 (Velocità creatura ≥ max squadra → fuga, altrimenti combatti), 229 (+1 ora).
  Nuovi rami in `paragraph_logic` (045/051/060/220) ed effetti in `_apply_paragraph_effect`
  (081/082/176/229).
- **Altri fatti → 🟢 (2026-06-15):** 037 (svanire + rilocalizzazione scanner → ¶020),
  042 (scelta «Riportala» con tiro 1d6 → acquisito/¶178/¶205, via `roll_goto`+`acquire`),
  050 (hub Azioni di Bordo 4.5: `_onboard_actions` cura+ripara), 145/159/167 (restrizioni
  fonti di combattimento, vedi §A residuo ¶043), 205 (Aggressività +2, ri-tiro 8.2),
  231 (imboscata anche all'ingresso in città aliena).
- **Residui 🟡 (caveat documentati):** 039 (rimando post-esito → ¶197), 063 (3 E-cage —
  conteggio E-cage non modellato), 114 (esplorazione in immersione non imposta),
  119/123/132 (ridefinizioni «struttura aliena» — non modellata come terreno), 024
  (duello «singolo personaggio» multi-stadio), 191 (perdita strumenti approssimata).

---

## 5. Note / rischi noti
- **Mappatura risultati combattimento — RISOLTO (2026-06-15).** Verificata sulle carte
  originali (Carte 8.4/8.6/8.7 in `Tabelle_Materiali/Voyage BSM Pandora`). Il proxy
  AE/AR/EX/DR/DE è sostituito dal modello reale: `combat_results.rows` in `tables.json`
  (6 righe-dado × 9 colonne-differenziale → A-E), `GameData.combat_result(diff, die, shift)`,
  esiti 8.7 per Uccidi/Cattura con Punti Danno reali (`_combat_damage`), e fix del combat
  rating creatura via lookup 8.4 (`roll_creature_combat_rating`, non più la somma grezza).
  Hook ¶218/¶227 e ¶193 riportati ad A-E. Smoke test headless superato. **Nota residua:**
  `best_combat` usa il miglior Valore singolo della squadra; la *somma* di gruppo resta un
  caso speciale da modellare (¶225) — vedi §4.C.
- **CI «Pubblica su Pages» fallisce** su tutti i commit del branch (pubblica solo da
  `main`): non è un errore del codice.
- Verificare sempre con smoke test prima di marcare 🟢; usare 🟡 con caveat quando si
  approssima (coerenza con la legenda del doc).
