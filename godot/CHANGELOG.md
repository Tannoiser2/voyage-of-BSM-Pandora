# Changelog — Voyage of the BSM Pandora (adattamento digitale)

Adattamento digitale in Godot del libro-gioco SPI *Voyage of the BSM Pandora* (1981).

## v0.9.0 — 2026-06-15

### Paragrafi: 100% (232/232 automatizzati, fedeli al regolamento)
Da 36% a inizio sessione a **100%**. Tutti i 232 paragrafi sono ora pienamente
gestiti dal motore (0 parziali, 0 mancanti).

- **Combattimento verificato sulle carte originali (8.4/8.6/8.7):** Tabella dei
  Risultati a 6 righe (dado) × 9 colonne (differenziale) → A-E; esiti distinti
  Uccidi/Cattura con Punti Danno reali (1/2/4/8/12); rating creatura via lookup 8.4;
  corretto il **segno** degli spostamenti di colonna (sinistra = sfavorevole).
- **Rig per-personaggio (5.2):** enviorig/armorig derivati dall'atmosfera; clausole
  «se il colpito indossa…» / «se tutti…» precise (035/147/166/180/216/005/008/197/224/030).
- **Effetti-sorpresa intro-creatura:** 031/057/075/142/149/151/153/179 + stordimento
  (027), spostamento a 1 dado, sterminio su D/E (153).
- **Combattimento avanzato:** 2 round (206), valore combinato del gruppo (225),
  modificatore +3 (217), duello «singolo personaggio» (024), Valori per-personaggio (055).
- **Restrizioni delle fonti di combattimento:** solo armorig/specibot/turbolaser (043),
  esclusioni netgun/stunbomb/turbolaser (031/159/167), filtro velocità (145).
- **Ridefinizioni di terreno per-area al deploy:** città→ghiaccio (117/126), caverne
  inesistenti (129/133), fiumi/paludi→ghiaccio (139), oceano/immersione (114/123/132).
- **Sistemi nuovi:** conteggio E-cage (063), Resistenza dei robot (155), hub Azioni di
  Bordo ¶050 (cura+riparazione), timing shuttle ¶163, imboscata razza ostile (231),
  game over automatico (081/082), e numerosi esiti minori.

### Interfaccia (UX)
- **Tema visivo coerente** ispirato alla copertina (blu notte, accenti ciano/ambra):
  pannelli con bordo, bottoni stilizzati, sfondo a gradiente.
- **Menu** con la **copertina** del gioco in grande e azioni prominenti.
- **Schermata di gioco**: pannello di stato riorganizzato in card a sezioni
  (Missione · Equipaggio · Dado · Punti Vittoria · Registro); esagoni trasparenti
  sulle mappe; pulsanti d'azione con colori distintivi.

### Verifica
- Smoke test headless per ogni blocco; playtest end-to-end del flusso completo
  (viaggio → orbita → sbarco → esplorazione → incontro → combattimento → rientro →
  azioni di bordo → salva/carica) superato.

### Note
- Restano da rifinire alcune **sezioni-regole di sistema** (9.2/9.3 scoring e
  condizioni di vittoria, 8.8/8.9 assorbimento danni e Porto, 5.6–5.8 rover/porto
  individuale): vedi `docs/STATO_REGOLE.md`.
