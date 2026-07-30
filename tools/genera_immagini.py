#!/usr/bin/env python3
"""Genera le illustrazioni dei paragrafi con Stable Diffusion in locale.

Legge il catalogo dei prompt (docs/immagini/prompts_*.json) e produce
`Event_NNN.jpg` in godot/assets/events/, già ridimensionate al formato usato
dal gioco (768x432).

Backend supportati:
  * a1111  — Automatic1111 / Forge WebUI, avviato con `--api` (default)
  * comfy  — ComfyUI, con un workflow txt2img minimo incorporato

Esempi:
    # prova a vuoto: mostra cosa verrebbe generato, senza chiamare nulla
    python3 tools/genera_immagini.py --dry-run

    # tutto il lotto pilota su A1111 in ascolto sulla porta 7860
    python3 tools/genera_immagini.py --api http://127.0.0.1:7860

    # rigenera solo due paragrafi venuti male, cambiando seed
    python3 tools/genera_immagini.py --only 69,170 --seed-offset 100

    # ComfyUI, indicando il checkpoint da usare
    python3 tools/genera_immagini.py --backend comfy --api http://127.0.0.1:8188 \
        --model sd_xl_base_1.0.safetensors

Richiede: Pillow (`pip install pillow`). Nient'altro: usa solo la libreria standard.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

RADICE = pathlib.Path(__file__).resolve().parent.parent
PROMPT_DEFAULT = RADICE / "docs" / "immagini" / "prompts_pilota.json"
USCITA_DEFAULT = RADICE / "godot" / "assets" / "events"


# --- utilità ----------------------------------------------------------------

def _post_json(url: str, payload: dict, timeout: int = 600) -> dict:
    dati = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=dati, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as risposta:
        return json.loads(risposta.read().decode("utf-8"))


def _get(url: str, timeout: int = 60) -> bytes:
    with urllib.request.urlopen(url, timeout=timeout) as risposta:
        return risposta.read()


def salva(immagine_bytes: bytes, destinazione: pathlib.Path, larghezza: int, altezza: int) -> None:
    """Ridimensiona al formato del gioco e salva come JPEG."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Serve Pillow: pip install pillow")
    img = Image.open(io.BytesIO(immagine_bytes)).convert("RGB")
    if img.size != (larghezza, altezza):
        img = img.resize((larghezza, altezza), Image.LANCZOS)
    destinazione.parent.mkdir(parents=True, exist_ok=True)
    img.save(destinazione, "JPEG", quality=88, optimize=True)


# --- backend ----------------------------------------------------------------

def genera_a1111(api: str, positivo: str, negativo: str, seed: int, w: int, h: int,
                 passi: int, cfg: float, sampler: str) -> bytes:
    payload = {
        "prompt": positivo,
        "negative_prompt": negativo,
        "seed": seed,
        "width": w,
        "height": h,
        "steps": passi,
        "cfg_scale": cfg,
        "sampler_name": sampler,
        "batch_size": 1,
        "n_iter": 1,
    }
    risposta = _post_json(f"{api.rstrip('/')}/sdapi/v1/txt2img", payload)
    immagini = risposta.get("images") or []
    if not immagini:
        raise RuntimeError("A1111 non ha restituito immagini")
    return base64.b64decode(immagini[0].split(",", 1)[-1])


def _workflow_comfy(modello: str, positivo: str, negativo: str, seed: int,
                    w: int, h: int, passi: int, cfg: float, sampler: str) -> dict:
    """Workflow txt2img minimo in formato API di ComfyUI."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": modello}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": positivo, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": negativo, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage",
              "inputs": {"width": w, "height": h, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": passi, "cfg": cfg,
                         "sampler_name": sampler, "scheduler": "normal", "denoise": 1.0,
                         "model": ["1", 0], "positive": ["2", 0],
                         "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode",
              "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "pandora", "images": ["6", 0]}},
    }


def genera_comfy(api: str, modello: str, positivo: str, negativo: str, seed: int,
                 w: int, h: int, passi: int, cfg: float, sampler: str,
                 attesa_max: int = 600) -> bytes:
    base = api.rstrip("/")
    wf = _workflow_comfy(modello, positivo, negativo, seed, w, h, passi, cfg, sampler)
    risposta = _post_json(f"{base}/prompt", {"prompt": wf})
    pid = risposta.get("prompt_id")
    if not pid:
        raise RuntimeError("ComfyUI non ha accettato il workflow")
    scadenza = time.time() + attesa_max
    while time.time() < scadenza:
        time.sleep(2)
        try:
            storico = json.loads(_get(f"{base}/history/{pid}").decode("utf-8"))
        except urllib.error.HTTPError:
            continue
        voce = storico.get(pid)
        if not voce:
            continue
        for uscita in voce.get("outputs", {}).values():
            for img in uscita.get("images", []):
                q = urllib.parse.urlencode({
                    "filename": img["filename"],
                    "subfolder": img.get("subfolder", ""),
                    "type": img.get("type", "output"),
                })
                return _get(f"{base}/view?{q}")
    raise TimeoutError("ComfyUI: nessuna immagine entro il tempo massimo")


# --- programma --------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--prompts", type=pathlib.Path, default=PROMPT_DEFAULT)
    p.add_argument("--out", type=pathlib.Path, default=USCITA_DEFAULT)
    p.add_argument("--backend", choices=["a1111", "comfy"], default="a1111")
    p.add_argument("--api", default="http://127.0.0.1:7860")
    p.add_argument("--model", default="sd_xl_base_1.0.safetensors", help="checkpoint (solo ComfyUI)")
    p.add_argument("--only", default="", help="solo questi paragrafi, es. 69,170")
    p.add_argument("--steps", type=int, default=30)
    p.add_argument("--cfg", type=float, default=6.5)
    p.add_argument("--sampler", default="dpmpp_2m")
    p.add_argument("--seed-offset", type=int, default=0, help="sposta i seed per rigenerare varianti")
    p.add_argument("--dry-run", action="store_true", help="stampa i prompt senza generare")
    args = p.parse_args()

    catalogo = json.loads(args.prompts.read_text(encoding="utf-8"))
    stile = catalogo["stile"]
    negativo = catalogo["negative"]
    gen_w, gen_h = catalogo["dimensioni"]["generazione"]
    out_w, out_h = catalogo["dimensioni"]["output"]
    seed_base = int(catalogo.get("seed_base", 0)) + args.seed_offset

    filtro = {int(x) for x in args.only.split(",") if x.strip()} if args.only else None
    voci = [v for v in catalogo["paragrafi"] if filtro is None or int(v["para"]) in filtro]
    if not voci:
        print("Nessun paragrafo selezionato.")
        return 1

    print(f"{len(voci)} immagini · backend {args.backend} · {gen_w}x{gen_h} → {out_w}x{out_h}")
    errori = 0
    for i, voce in enumerate(voci, 1):
        numero = int(voce["para"])
        positivo = f"{voce['prompt']}, {stile}"
        seed = seed_base + numero
        destinazione = args.out / f"Event_{numero:03d}.jpg"
        print(f"[{i}/{len(voci)}] ¶{numero:03d} ({voce.get('tipo','?')}) seed {seed}")
        if args.dry_run:
            print(f"    {positivo}")
            continue
        try:
            if args.backend == "a1111":
                dati = genera_a1111(args.api, positivo, negativo, seed, gen_w, gen_h,
                                    args.steps, args.cfg, args.sampler)
            else:
                dati = genera_comfy(args.api, args.model, positivo, negativo, seed,
                                    gen_w, gen_h, args.steps, args.cfg, args.sampler)
            salva(dati, destinazione, out_w, out_h)
            print(f"    → {destinazione.relative_to(RADICE)}")
        except Exception as errore:            # noqa: BLE001 - vogliamo proseguire col lotto
            errori += 1
            print(f"    ERRORE: {errore}")

    if errori:
        print(f"\nCompletato con {errori} errori.")
        return 1
    print("\nCompletato.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
