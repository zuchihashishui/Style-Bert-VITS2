"""So sanh nhanh cac checkpoint Takumi: sinh audio cung cau, do cac chi so don gian."""

import json
import time
from pathlib import Path

import numpy as np
import soundfile as sf

from style_bert_vits2.constants import Languages
from style_bert_vits2.tts_model import TTSModel

ASSETS = Path(r"C:\project\Style-Bert-VITS2\model_assets\Takumi")
OUT = Path(r"C:\project\Style-Bert-VITS2\_eval_out")
OUT.mkdir(exist_ok=True)

TEXTS = [
    "おはよう、いい天気だね。",
    "そんなこと言われても、困るよ。",
    "今日は少し遅くなるかもしれないから、先にご飯を食べていてください。それと、明日の約束はまだ生きているのかな。",
]

CHECKPOINTS = [
    "Takumi_e38_s20982.safetensors",
    "Takumi_e43_s24000.safetensors",
    "Takumi_e48_s26900.safetensors",
]

cfg = json.loads((ASSETS / "config.json").read_text(encoding="utf-8"))
style2id = (cfg.get("data") or {}).get("style2id") or {}
style_name = next(iter(style2id.keys()), "Neutral")
print("style:", style_name, "| style2id:", style2id, flush=True)


def to_int16(audio) -> np.ndarray:
    a = np.asarray(audio)
    if a.dtype == np.int16:
        return a
    a = a.astype(np.float32)
    if np.abs(a).max() > 1.5:
        a = a / 32768.0
    return np.clip(a * 32767.0, -32768, 32767).astype(np.int16)


def metrics(audio: np.ndarray, sr: int) -> dict:
    x = audio.astype(np.float32) / 32768.0
    frame = max(1, int(sr * 0.02))
    n = len(x) - len(x) % frame
    frames = x[:n].reshape(-1, frame)
    rms_frames = np.sqrt((frames**2).mean(axis=1) + 1e-12)
    peak = float(np.abs(x).max())
    clipped = float((np.abs(x) > 0.999).mean())
    # khoang lang o cuoi
    thr = rms_frames.max() * 0.02
    voiced = np.where(rms_frames > thr)[0]
    tail_sil = (
        float((len(rms_frames) - 1 - voiced[-1]) * frame / sr) if len(voiced) else -1
    )
    # do "deu" cua nang luong: do lech chuan cua rms tren cac khung co tieng
    voiced_rms = rms_frames[rms_frames > thr]
    return {
        "dur_s": round(len(x) / sr, 2),
        "peak": round(peak, 3),
        "clip_ratio": round(clipped, 5),
        "rms": round(float(np.sqrt((x**2).mean())), 4),
        "tail_silence_s": round(tail_sil, 2),
        "voiced_ratio": round(len(voiced) / max(1, len(rms_frames)), 3),
        "rms_cv": round(float(voiced_rms.std() / (voiced_rms.mean() + 1e-9)), 3),
    }


for ckpt in CHECKPOINTS:
    t0 = time.time()
    model = TTSModel(
        model_path=ASSETS / ckpt,
        config_path=ASSETS / "config.json",
        style_vec_path=ASSETS / "style_vectors.npy",
        device="cuda",
    )
    model.load()
    load_s = time.time() - t0
    for i, text in enumerate(TEXTS, start=1):
        sr, audio = model.infer(
            text=text, language=Languages.JP, style=style_name, line_split=False
        )
        pcm = to_int16(audio)
        sf.write(OUT / f"{ckpt.replace('.safetensors','')}_t{i}.wav", pcm, sr)
        m = metrics(pcm, sr)
        print(f"{ckpt} | t{i} {text} -> {m}", flush=True)
    print(f"  (load {load_s:.0f}s)", flush=True)
    del model
    import torch

    torch.cuda.empty_cache()

print("done ->", OUT, flush=True)
