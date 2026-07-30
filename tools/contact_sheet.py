#!/usr/bin/env python3
"""Crea un foglio di controllo HTML: ogni immagine accanto al testo del suo paragrafo.

Serve a scovare in fretta le illustrazioni che non c'entrano nulla col paragrafo —
il difetto delle immagini attuali. Si apre nel browser e si scorre.

Esempi:
    # solo i paragrafi del catalogo pilota
    python3 tools/contact_sheet.py

    # tutti i 232, per la revisione generale
    python3 tools/contact_sheet.py --tutti

Il file esce in docs/immagini/controllo.html (non versionato se preferisci).
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import os
import pathlib
import re

RADICE = pathlib.Path(__file__).resolve().parent.parent
PARAGRAFI = RADICE / "godot" / "data" / "paragrafi_it.json"
IMMAGINI = RADICE / "godot" / "assets" / "events"
PROMPT_DEFAULT = RADICE / "docs" / "immagini" / "prompts_pilota.json"
USCITA = RADICE / "docs" / "immagini" / "controllo.html"

CSS = """
body{background:#0f1420;color:#e6e9ef;font:15px/1.5 system-ui,sans-serif;margin:0;padding:24px}
h1{font-size:20px;color:#7fc7ff;margin:0 0 4px}
p.sub{color:#8fa6c0;margin:0 0 24px}
.riga{display:flex;gap:16px;align-items:flex-start;padding:14px;margin-bottom:12px;
      background:#151c2b;border:1px solid #24304a;border-radius:8px}
.riga img{width:384px;height:216px;object-fit:cover;border-radius:5px;flex:none;background:#000}
.testo{flex:1;min-width:0}
.num{color:#ffd24d;font-weight:600;margin-bottom:6px}
.tipo{color:#7fc7ff;font-size:12px;text-transform:uppercase;letter-spacing:.05em}
.para{color:#c8d2e0}
.prompt{margin-top:8px;color:#8fa6c0;font-size:13px;font-style:italic}
.manca{color:#ff8866}
"""


def testo_paragrafo(dati: dict, numero: int) -> str:
    voce = dati.get("%03d" % numero) or dati.get(str(numero)) or {}
    testo = voce.get("it", "") if isinstance(voce, dict) else str(voce)
    return re.sub(r"\s+", " ", testo).strip()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--prompts", type=pathlib.Path, default=PROMPT_DEFAULT)
    p.add_argument("--tutti", action="store_true", help="tutti i 232 paragrafi, non solo quelli del catalogo")
    p.add_argument("--embed", action="store_true", help="incorpora le immagini nel file (autonomo ma pesante)")
    p.add_argument("--out", type=pathlib.Path, default=USCITA)
    args = p.parse_args()

    paragrafi = json.loads(PARAGRAFI.read_text(encoding="utf-8"))
    prompt_per_para: dict[int, dict] = {}
    if args.prompts.exists():
        catalogo = json.loads(args.prompts.read_text(encoding="utf-8"))
        prompt_per_para = {int(v["para"]): v for v in catalogo.get("paragrafi", [])}

    numeri = list(range(1, 233)) if args.tutti else sorted(prompt_per_para)
    righe = []
    for numero in numeri:
        percorso = IMMAGINI / f"Event_{numero:03d}.jpg"
        if percorso.exists():
            if args.embed:
                b64 = base64.b64encode(percorso.read_bytes()).decode("ascii")
                fonte = f"data:image/jpeg;base64,{b64}"
            else:
                # percorso relativo alla posizione del file HTML: resta leggero
                fonte = os.path.relpath(percorso, args.out.parent).replace("\\", "/")
            img = f'<img src="{fonte}" alt="¶{numero:03d}">'
        else:
            img = '<div class="riga-img manca">immagine assente</div>'
        voce = prompt_per_para.get(numero, {})
        tipo = html.escape(str(voce.get("tipo", "")))
        prompt = html.escape(str(voce.get("prompt", "")))
        righe.append(
            f'<div class="riga">{img}<div class="testo">'
            f'<div class="num">¶{numero:03d} <span class="tipo">{tipo}</span></div>'
            f'<div class="para">{html.escape(testo_paragrafo(paragrafi, numero))}</div>'
            + (f'<div class="prompt">prompt: {prompt}</div>' if prompt else "")
            + "</div></div>"
        )

    documento = (
        "<!doctype html><meta charset='utf-8'><title>Controllo immagini</title>"
        f"<style>{CSS}</style>"
        "<h1>Controllo immagini dei paragrafi</h1>"
        f"<p class='sub'>{len(numeri)} paragrafi. Scorri e segna quelli in cui l'immagine "
        "non corrisponde al testo: si rigenerano con "
        "<code>tools/genera_immagini.py --only N,M</code>.</p>"
        + "".join(righe)
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(documento, encoding="utf-8")
    print(f"Scritto {args.out.relative_to(RADICE)} ({len(numeri)} paragrafi)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
