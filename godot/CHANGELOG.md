# Changelog — Voyage of the BSM Pandora (adattamento digitale)

Adattamento digitale in Godot del libro-gioco SPI *Voyage of the BSM Pandora* (1981).

## v0.10.0 — 2026-06-16

### Diario «Cosa succede» — la finestra centrale è il cuore dell'azione
- **Testo e logica uniti al centro.** La finestra principale ora mostra, oltre al
  testo del paragrafo, **cosa succede** durante l'azione: controlli, esiti, danni e
  conseguenze. Il **Registro di Bordo** a destra resta la memoria storica completa.
- **Controlli espliciti.** Quando un paragrafo verifica la presenza di un
  robot/strumento/personaggio o una condizione (atmosfera, rig), ora scrive
  «Controllo — c'è X? ▸ Sì/No → conseguenza» invece di risolverlo in silenzio
  (22 controlli espliciti aggiunti: ¶038, 166, 158, 028, 176, 197, 224, 209, 216,
  218, 226, 043, 066, 162, 208, 187, 193, 037, 024, …).
- **Formule collassabili.** La matematica del **Controllo del Rifornimento** (7.2)
  e del **combattimento** (8.5: squadra vs creatura → differenziale, dado →
  risultato A–E) è raccolta in una sezione «▶ formule e controlli» espandibile, che
  non ingombra la narrazione.
- **Controllo del Rifornimento chiaro.** Il diario spiega **quando** scatta (la
  Traccia del Tempo ha raggiunto la soglia di ore data dalla gravità, 6.8) e
  l'esito della spesa.
- **Esteso a tutte le fasi.** Il diario copre ora anche **viaggio interstellare** e
  **orbita** (arrivo nel sistema, controllo evento 4.0, eventi 4.2), non solo la
  spedizione planetaria.

### Interfaccia
- **Stato della Missione** con **barre**: Traccia del Tempo (ore al prossimo
  Controllo del Rifornimento) e Rifornimenti della spedizione.
- **Disposizione** ribilanciata: box Shuttle / A piedi / Rover di **larghezza
  uguale**; box di superficie più alti con etichetta **carico/Porto e rifornimenti**;
  box Pandora dimensionato per contenere le **tre file** di pedine senza tagli.

### Correzioni
- **Tabelle di riferimento e changelog** ora inclusi nel build Web (GitHub Pages):
  i file dati (`*.json`) e i documenti (`*.md`) vengono pacchettizzati nell'export.

## v0.9.2 — 2026-06-15

### Esplorazione e incontri
- **Più varietà negli incontri (6.5):** quando le condizioni di uno snodo non
  combaciano si **ri-tira la Matrice di Esplorazione** (varietà reale) invece di
  convergere su pochi paragrafi.
- **Logica di scelta visibile:** il box di testo centrale mostra ora «Come ci sei
  arrivato» (mossa, tiri della Matrice, instradamento snodo, Controllo del
  Rifornimento), non solo il registro.
- **Presidio dello shuttle (5.6):** sulla superficie un'unità può restare a guardia
  dello shuttle (clic sulla pedina); così l'esagono è «occupato» ed eventi come il
  **¶163** (insetti mangia-metallo) non si innescano di continuo.

### Interfaccia
- **Pedine della Disposizione più grandi e uniformi**, con dimensione calcolata
  perché **entrino tutte** in ogni box (niente scroll, niente tagli).

## v0.9.1 — 2026-06-15

### Regole di sistema completate
- **Danni e Porto (8.8/8.9):** ogni Punto Resistenza perso riduce di 1 il Valore di
  Porto del personaggio (i Punti Danno «riducono il Porto»); il Porto non scende
  sotto zero.
- **Scoring di fine gioco (9.2):** oltre a personaggio ucciso −10 e Resistenza
  sopravvissuti −1, ora si applicano **−1 per robot/rover danneggiato**, **−1 per
  tipo di strumento danneggiato** (registro persistente svuotato dalla riparazione
  al ¶050), **−5 per riga del Crew Log** (personaggio perso) e −5 per mese oltre il Tour.
- **Condizione di vittoria (9.3):** verdetto finale `win`/`lose` — vittoria se i PV
  sono almeno il doppio dei mesi del Tour scelto.
- **Capacità di Porto per gravità (5.8):** capacità di shuttle e **rover**
  (50/40/30/20/—) e Valore di Porto di personaggi/bot/strumenti scalati dalla gravità
  (×2/+2/=/−2/½); il rover è **vietato in gravità opprimente**.
- **Spedizione in Rover o a piedi (5.6/5.7):** la squadra è *o* nel Rover *o* a piedi
  (scelta del mezzo); sull'environ lo **shuttle resta sul landing hex** («S») e la
  squadra si muove col proprio segnalino («R» rover / «P» piedi).

### Interfaccia (UX)
- **Pannello Disposizione** ridisegnato: Pandora in alto a tutta larghezza, sotto
  Shuttle (più grande) e **un solo** box di superficie (Rover *oppure* A piedi);
  pedine di **dimensione uniforme** disposte in righe per categoria (equipaggio ·
  equipaggiamento · robot) con a-capo automatico. Riga informativa con **fase
  corrente** e **capacità di Porto di superficie**, più il pulsante per scegliere il mezzo.

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
