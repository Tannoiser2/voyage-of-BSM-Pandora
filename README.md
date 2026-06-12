# Il Viaggio della B.S.M. Pandora — versione digitale (Godot, in italiano)

Ricostruzione digitale in **Godot 4** del gioco in solitario *Voyage of the B.S.M. Pandora*
(SPI, pubblicato su **Ares Magazine n. 11**, © 1981 Simulations Publications, Inc.),
**interamente tradotto in italiano** (regole e tutti i 232 paragrafi-evento).

Gli asset grafici originali (mappa, pedine, carte) provengono dal modulo Vassal ufficiale,
usato come fonte dei "pezzi" del gioco. **Solo per uso personale.**

## Stato del progetto

| Componente | Stato |
|---|---|
| Import asset originali (424 immagini) | ✅ fatto (`godot/assets/`) |
| Traduzione regole (sez. 1.0–9.0) | ✅ `docs/regolamento_it.md` |
| Trascrizione + traduzione 232 paragrafi | 🚧 in corso — **priorità** — `godot/data/paragrafi_it.json` |
| Traduzione tabelle/carte | 🔜 `docs/tabelle_it.md` |
| Dati pedine (personaggi/robot/strumenti/creature) | 🔜 `godot/data/*.json` |
| Progetto Godot (scene, UI, logica) | 🔜 in corso |

## Struttura

```
docs/                      Documentazione e traduzioni (regole, tabelle)
godot/                     Progetto Godot 4
  assets/                  Grafica originale, organizzata per categoria
    map/ creatures/ characters/ bots/ tools/ artifacts/
    markers/ icons/ charts/ events/ dice/
  data/                    Dati di gioco in JSON (italiano)
  scenes/                  Scene Godot (.tscn)
  scripts/                 Logica di gioco (GDScript)
```

## Come è strutturato il gioco originale

Gioco in solitario *event-driven*: non c'è una sequenza di turni fissa, ma una catena di
**232 paragrafi** (come un librogame) collegati da carte, tabelle e lanci di dado. Il giocatore
comanda la nave **Pandora**, viaggia tra i sistemi stellari (Display Interstellare), prepara
**spedizioni** che scendono su pianeti per esplorarne le **aree** (environ) esagonali,
incontrando creature e artefatti da catturare per ottenere **Punti Vittoria**.

Due scale temporali: il **Tour di Servizio** in mesi (10/20/30) e il tempo di **spedizione** in ore.

Vedi `docs/regolamento_it.md` per il regolamento completo tradotto.
