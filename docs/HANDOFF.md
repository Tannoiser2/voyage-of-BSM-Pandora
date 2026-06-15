# Handoff — riprendere il lavoro (Voyage of the BSM Pandora)

**Ultimo aggiornamento:** 2026-06-15 · **Branch:** `claude/tabelle-materiale-voyage-bsm-iaeefu` (PR #29 mergiata in `main`)

Documento per ripartire in una nuova sessione. Riassume **dove siamo**, **come
funziona il codice** e **cosa resta da fare** (i 55 🟡).

---

## 1. Stato attuale

Adattamento digitale Godot del libro-gioco SPI (232 paragrafi). Vedi
`docs/STATO_PARAGRAFI.md` (tabella 1:1) e `docs/STATO_REGOLE.md` (per sezione).

| Stato | Conteggio | Indice di completezza |
|---|---|---|
| 🟢 Verde | 182 | |
| 🟡 Giallo | 50 | **≈ 89,2%** |
| 🔴 Rosso | **0** | (da 36,0% a inizio sessione) |

**Nessun paragrafo è più completamente non gestito.** I 🟡 hanno tutti un
*caveat documentato* (non sono funzionalità mancanti).

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
  `https://claude.ai/code/session_...`. **Push** su `claude/spi-game-godot-digital-fb861w`.
  NON pushare su altri branch.
- **Doc:** dopo ogni batch, aggiornare `docs/STATO_PARAGRAFI.md` (riga del paragrafo,
  conteggi riepilogo, indice, tabella per-tipo, **Totale**). Le % usano la **virgola**.

---

## 3. Architettura: dove sta cosa (file e funzioni chiave)

Tutto il motore è in `godot/scripts/GameState.gd` (+ `GameData.gd`, `GameScreen.gd`).

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

## 4. TODO per la prossima sessione (rifinire i 55 🟡)

Ordine consigliato: dal più sistematico (sblocca molti) al più di nicchia.

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
- **Residuo (¶043):** la clausola «in combattimento valgono solo i Valori di
  armorig/specibot/turbolaser» (restrizione delle fonti di combattimento) non è
  ancora modellata — richiede un hook in `best_combat`. ¶043 resta 🟡 per questo.

### B. intro-creatura (effetti sorpresa) (8)
Paragrafi: 031, 057, 075, 142, 149, 151, 153, 179.
- Aggiungere/precisare gli effetti-intro in `_apply_creature_intro` (e
  `paragraph_logic` dove serve). Leggere il testo di ciascuno e codificare l'effetto
  di sorpresa specifico. 057: il danno ai robot va legato a Comunica/Combatti, non
  all'intro.

### C. combattimento (round/valore combinato) (9)
Paragrafi: 024, 027, 048, 055, 072, 191, 206, 217, 225.
- **206:** combattimento a 2 round con risultati riletti + aumento del Valore di
  Combattimento della creatura per il 2° round. Serve estendere `resolve_combat`
  (concetto di round + risultati custom A/B/C/D/E → effetti).
- **225:** combattimento col **valore combinato** del gruppo (somma combat) e
  risultato «E» a 12 danni. Modellare il gruppo come singola creatura con rating somma.
- **055/191/217:** già parziali (alcuni Valori non memorizzati per personaggio →
  legati al punto A).

### D. ridefinizioni terreno / vincoli d'area (7)
Paragrafi: 076, 114, 117, 126, 129, 133, 139.
- Applicare le ridefinizioni di terreno per-area all'atterraggio (es. «tutti gli
  esagoni di città aliena = ghiaccio glaciale», «le caverne non esistono»). Si può
  fare modificando `environ_grid` al deploy in base al paragrafo d'atterraggio.
- Vincoli «non lasciare l'area finché…» (076) → flag + check sul movimento.

### E. timing (1)
- **163:** shuttle divorato se non si torna prima del prossimo Controllo del
  Rifornimento → ¶050. Serve un flag con scadenza al prossimo supply check.

### F. altro/minore (24)
Paragrafi: 033, 037, 039, 042, 045, 050, 051, 060, 063, 081, 082, 119, 123, 132,
145, 159, 167, 176, 205, 220, 229, 231 (+ 155 in A/E).
- Caso per caso: rileggere il testo, vedere il caveat nella nota di
  `STATO_PARAGRAFI.md` e completare l'effetto mancante. Molti sono piccoli (un PV
  condizionale, un dettaglio non applicato).

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
