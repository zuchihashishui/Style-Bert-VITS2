"""Synthesize a Japanese text script into audio with a trained Style-Bert-VITS2 model."""

import argparse
import re
import time
from pathlib import Path

import numpy as np
import soundfile as sf

from style_bert_vits2.constants import Languages
from style_bert_vits2.tts_model import TTSModel


def to_int16(audio) -> np.ndarray:
    """Convert model output (int16, or float scaled either way) to int16 PCM samples."""
    a = np.asarray(audio)
    if a.dtype == np.int16:
        return a
    a = a.astype(np.float32)
    if np.abs(a).max() > 1.5:
        a = a / 32768.0
    return np.clip(a * 32767.0, -32768, 32767).astype(np.int16)


def split_chunks(text: str, max_len: int = 110) -> list[str]:
    """Split text into chunks of at most max_len chars, breaking at sentence ends."""
    sentences = [s for s in re.split(r"(?<=[。！？!?])", text) if s.strip()]
    chunks: list[str] = []
    buf = ""
    for s in sentences:
        if len(buf) + len(s) <= max_len:
            buf += s
        else:
            if buf:
                chunks.append(buf)
            buf = s
    if buf:
        chunks.append(buf)
    return chunks


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", required=True)
    parser.add_argument("--model-dir", default="model_assets/ren")
    parser.add_argument("--model-file", default="ren_e35_s15000.safetensors")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--style", default="Neutral")
    parser.add_argument("--max-len", type=int, default=110)
    args = parser.parse_args()

    model_dir = Path(args.model_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    text = Path(args.text).read_text(encoding="utf-8")
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    print(f"paragraphs: {len(paragraphs)}", flush=True)

    model = TTSModel(
        model_path=model_dir / args.model_file,
        config_path=model_dir / "config.json",
        style_vec_path=model_dir / "style_vectors.npy",
        device=args.device,
    )
    model.load()

    sr_ref: int | None = None
    full: list[np.ndarray] = []
    t_start = time.time()

    for i, para in enumerate(paragraphs, start=1):
        chunks = split_chunks(para, args.max_len)
        audio_parts: list[np.ndarray] = []
        for chunk in chunks:
            sr, audio = model.infer(
                text=chunk,
                language=Languages.JP,
                style=args.style,
                line_split=False,
            )
            if sr_ref is None:
                sr_ref = sr
            audio_parts.append(to_int16(audio))
            audio_parts.append(np.zeros(int(sr * 0.35), dtype=np.int16))
        audio = np.concatenate(audio_parts)
        sf.write(out_dir / f"part_{i:02d}.wav", audio, sr_ref, subtype="PCM_16")
        full.append(audio)
        full.append(np.zeros(int(sr_ref * 0.8), dtype=np.int16))
        elapsed = time.time() - t_start
        dur = len(audio) / sr_ref
        print(
            f"[{i}/{len(paragraphs)}] {dur:6.1f}s audio, "
            f"{len(chunks)} chunks, elapsed {elapsed/60:.1f} min",
            flush=True,
        )

    full_audio = np.concatenate(full)
    full_path = out_dir / "full.wav"
    sf.write(full_path, full_audio, sr_ref, subtype="PCM_16")
    peak = float(np.abs(full_audio).max()) / 32768.0
    rms = float(np.sqrt((full_audio.astype(np.float32) ** 2).mean())) / 32768.0
    print(
        f"total {len(full_audio)/sr_ref/60:.1f} min -> {full_path} "
        f"(peak {peak:.2f}, rms {rms:.3f})",
        flush=True,
    )


if __name__ == "__main__":
    main()
