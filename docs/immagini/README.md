# Illustrazioni dei paragrafi — come rifarle

## Perché rifarle

Le 232 immagini attuali (`godot/assets/events/Event_NNN.jpg`) **non sono state generate
dal testo del paragrafo**: sembrano prodotte da un tema generico «paesaggio alieno».

La prova sta nel confronto:

| Paragrafo | Testo originale | Immagine attuale |
|---|---|---|
| ¶002 | «Mentre lo shuttle scende, problemi meccanici… minacciano di provocare un incidente» | fulmini viola su rocce |
| ¶069 | «una creatura umanoide lunga e magra… viscere gorgoglianti attraverso la pelle traslucida» | **gli stessi** fulmini viola su rocce |
| ¶136 | «atterrato su lava indurita… il bagliore della roccia fusa a ovest» | colate di lava — *azzeccata* |

Il pattern: i paragrafi che descrivono un **paesaggio** funzionano per caso, quelli con
**creature, eventi o interni della nave** no.

## Il flusso di lavoro

### 1. Il catalogo dei prompt

`prompts_pilota.json` contiene, per ogni paragrafo: il **tipo** (creatura / atterraggio /
evento / interno nave / orbita), la **scena in italiano** ricavata dal testo originale e il
**prompt in inglese** per il generatore.

Nel file stanno anche i parametri comuni, che garantiscono coerenza fra tutte le immagini:

- `stile` — il blocco aggiunto in coda a ogni prompt (illustrazione da copertina sci-fi
  anni '80, gouache e aerografo, palette desaturata, luce singola)
- `negative` — cosa evitare (testo, watermark, cornici, stile cartoon, mani deformi…)
- `dimensioni` — si genera a 1024×576 e si riduce a **768×432**, il formato usato dal gioco
- `seed_base` — il seed di ogni immagine è `seed_base + numero di paragrafo`, così una
  rigenerazione a parità di prompt dà lo stesso risultato

Il lotto attuale è un **pilota di 20 paragrafi** scelti per coprire tutti i tipi: ¶001, 002,
044, 050, 058, 064, 066, 069, 070, 094, 114, 136, 139, 141, 148, 153, 162, 170, 201, 223.

### 2. La generazione

Richiede Stable Diffusion in locale e `pip install pillow`.

```bash
# 1. controlla i prompt senza generare nulla
python3 tools/genera_immagini.py --dry-run

# 2. genera il lotto pilota (Automatic1111/Forge avviato con --api)
python3 tools/genera_immagini.py --api http://127.0.0.1:7860

# ...oppure con ComfyUI, indicando il checkpoint
python3 tools/genera_immagini.py --backend comfy --api http://127.0.0.1:8188 \
    --model sd_xl_base_1.0.safetensors
```

Le immagini finiscono direttamente in `godot/assets/events/`, già ridimensionate: il gioco
le usa senza altri passaggi.

### 3. Il controllo

```bash
python3 tools/contact_sheet.py          # solo il lotto del catalogo
python3 tools/contact_sheet.py --tutti  # tutti i 232, per la revisione generale
```

Apri `docs/immagini/controllo.html`: ogni immagine è affiancata al testo del suo paragrafo.
Segna quelle che non c'entrano e rigenerale, cambiando seed per avere una variante diversa:

```bash
python3 tools/genera_immagini.py --only 69,170 --seed-offset 100
```

### 4. Estendere agli altri 212

Il formato è già pronto: basta aggiungere voci a `paragrafi` nello stesso file (o creare
`prompts_completo.json` e passarlo con `--prompts`). Per ogni paragrafo servono solo `para`,
`tipo`, `scena` e `prompt` — stile, negative, dimensioni e seed restano condivisi.

Regola pratica per scrivere il prompt: **descrivi ciò che il paragrafo fa vedere**, non ciò
che fa fare. «Tira due dadi e confronta con l'Intelligenza» non è una scena; «lo shuttle
scende con un propulsore in avaria» sì.

## Nota sui paragrafi senza scena

Alcuni paragrafi sono pura procedura (es. ¶070, ¶148: tiri di dado e rimandi). Lì l'immagine
illustra la **conseguenza** descritta nel testo — l'atterraggio duro, lo schianto — non la
procedura. Se un paragrafo non ha proprio nulla da mostrare, è meglio **nessuna immagine**
che una sbagliata: il gioco nasconde da solo la colonna dell'immagine quando il file manca.
