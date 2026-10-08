#!/usr/bin/env python3
"""
Монгол нэр + гэрийн чимээ таних туршилтын систем
 
1) Монгол нэр  -> MFCC + DTW (өөрөө бүртгүүлсэн бичлэгтэй харьцуулна)
2) Чимээ        -> Google-ийн YAMNet AI загвар (521 төрлийн дуу таньдаг)
   - Шил / аяга хагарах
   - Хаалга тогших
   - Хаалганы хонх
   - Хаалга хаагдах / онгойх
 
Хэрэглээ:
  python sound_detector.py enroll Өлзий             # нэр бүртгэх (5 удаа бичүүлнэ)
  python sound_detector.py import Өлзий <хавтас>    # TTS/бусад .wav файлуудаас нэмж бүртгэх
  python sound_detector.py list                     # бүртгэлтэй нэрс
  python sound_detector.py listen                    # нэр + чимээ бүгдийг сонсох
  python sound_detector.py listen -v                 # оноонуудыг харуулах (тохируулахад)
  python sound_detector.py listen --no-names         # зөвхөн чимээ
  python sound_detector.py listen --no-sounds        # зөвхөн нэр
"""
import argparse
import csv
import json
import os
import queue
import time
from pathlib import Path
 
import librosa
import numpy as np
import sounddevice as sd
 
# ---------------- Ерөнхий тохиргоо ----------------
SR = 16000               # дууны давтамж (YAMNet 16kHz шаарддаг)
HOP_SECONDS = 0.25       # хэдэн секунд тутам шалгах
WINDOW_SECONDS = 2.0     # нэр сонсох цонх
SOUND_WINDOW = 1.0       # чимээ сонсох цонх (YAMNet >= 0.96 сек)
SILENCE_RMS = 0.003      # нэр шалгах доод чимээ (микрофоноос хамаарна)
COOLDOWN_SECONDS = 2.5   # нэг зүйлийг таньсны дараа амрах хугацаа
DATA_DIR = Path(__file__).parent / "names"
 
# Нэр бүртгэл
ENROLL_SECONDS = 2.0
N_SAMPLES = 5
 
# YAMNet-ийн ангиллуудыг Монгол үйл явдал руу буулгах.
# threshold: 0-1 хооронд, бага бол амархан танина (буруу дохио ихэснэ).
SOUND_EVENTS = {
    "🪟 Шил / аяга хагарах": {"classes": ["Shatter", "Glass", "Breaking", "Smash, crash"], "threshold": 0.30},
    "✊ Хаалга тогших":      {"classes": ["Knock"], "threshold": 0.30},
    "🔔 Хаалганы хонх":      {"classes": ["Doorbell", "Ding-dong"], "threshold": 0.30},
    "🚪 Хаалга хаагдах/онгойх": {"classes": ["Door", "Slam", "Sliding door"], "threshold": 0.35},
}
 
 
# =====================================================================
# 1. МОНГОЛ НЭР ТАНИХ (MFCC + DTW)
# =====================================================================
def record(seconds):
    audio = sd.rec(int(seconds * SR), samplerate=SR, channels=1, dtype="float32")
    sd.wait()
    return audio[:, 0]
 
 
def trim(audio):
    trimmed, _ = librosa.effects.trim(audio, top_db=25)
    return trimmed
 
 
def extract_features(audio):
    mfcc = librosa.feature.mfcc(y=audio, sr=SR, n_mfcc=20, n_fft=512, hop_length=160)[1:]
    feats = np.vstack([mfcc, librosa.feature.delta(mfcc)])
    return (feats - feats.mean(axis=1, keepdims=True)) / (feats.std(axis=1, keepdims=True) + 1e-8)
 
 
def match_cost(template, feats):
    if feats.shape[1] < template.shape[1] // 2:
        return np.inf
    D, _ = librosa.sequence.dtw(X=template, Y=feats, metric="cosine", subseq=True)
    return float(D[-1, :].min() / template.shape[1])
 
 
def recompute_threshold(folder):
    """Тухайн хавтас дахь бүх sample_*.npy дээр үндэслэн босгыг дахин тооцоолно."""
    samples = sorted(folder.glob("sample_*.npy"))
    clips = [np.load(p) for p in samples]
    feats = [extract_features(c) for c in clips]
    costs = [match_cost(feats[a], feats[b])
             for a in range(len(feats)) for b in range(len(feats)) if a != b]
    costs = [c for c in costs if np.isfinite(c)]
    if not costs:
        return 0.5  # нөөц утга, хэрэв зөвхөн 1 sample байвал
    return float(np.max(costs) * 1.25)
 
 
def enroll(name):
    folder = DATA_DIR / name
    folder.mkdir(parents=True, exist_ok=True)
    print(f"\n'{name}' нэрийг {N_SAMPLES} удаа бичүүлнэ.")
    print("Зөвлөгөө: өөр өөр хүнээр, өөр өнгө аясаар дуудуулбал илүү сайн танина.")
 
    clips, i = [], 0
    while i < N_SAMPLES:
        input(f"\n[{i + 1}/{N_SAMPLES}] Enter дараад '{name}' гэж дуудаарай...")
        print("🎙  Бичиж байна...")
        audio = trim(record(ENROLL_SECONDS))
        if len(audio) / SR < 0.25:
            print("⚠️  Дуу сонсогдсонгүй, дахин оролдоорой.")
            continue
        np.save(folder / f"sample_{i}.npy", audio)
        clips.append(audio)
        print(f"✅ Хадгаллаа ({len(audio) / SR:.2f} сек)")
        i += 1
 
    threshold = recompute_threshold(folder)
    meta = {"name": name, "threshold": threshold}
    (folder / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n🎉 '{name}' бүртгэгдлээ (босго {threshold:.3f})")
 
 
def import_audio(name, source_dir):
    """Chimege TTS зэргээр урьдчилан үүсгэсэн .wav/.mp3 файлуудыг нэрэнд нэмж бүртгэнэ."""
    folder = DATA_DIR / name
    folder.mkdir(parents=True, exist_ok=True)
 
    source = Path(source_dir)
    if not source.exists():
        print(f"⚠️  '{source_dir}' хавтас олдсонгүй.")
        return
 
    audio_files = sorted(list(source.glob("*.wav")) + list(source.glob("*.mp3")))
    if not audio_files:
        print(f"⚠️  '{source_dir}' дотор .wav/.mp3 файл олдсонгүй.")
        return
 
    # Одоо байгаа sample дугааруудын дараа үргэлжлүүлнэ (хуучныг дарахгүй)
    existing = sorted(folder.glob("sample_*.npy"))
    start_idx = 0
    for p in existing:
        try:
            idx = int(p.stem.split("_")[1])
            start_idx = max(start_idx, idx + 1)
        except (IndexError, ValueError):
            continue
 
    print(f"\n'{name}' руу {len(audio_files)} файлаас импортолж байна...")
    added = 0
    for path in audio_files:
        try:
            audio, _ = librosa.load(str(path), sr=SR, mono=True)
        except Exception as e:
            print(f"❌ {path.name}: уншиж чадсангүй ({e})")
            continue
        audio = trim(audio)
        if len(audio) / SR < 0.25:
            print(f"⚠️  {path.name}: дуу хэт богино, алгаслаа.")
            continue
        idx = start_idx + added
        np.save(folder / f"sample_{idx}.npy", audio)
        print(f"✅ {path.name} -> sample_{idx}.npy ({len(audio) / SR:.2f} сек)")
        added += 1
 
    if added == 0:
        print("\nНэмэгдсэн файл алга.")
        return
 
    threshold = recompute_threshold(folder)
    meta = {"name": name, "threshold": threshold}
    (folder / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
 
    total = len(sorted(folder.glob("sample_*.npy")))
    print(f"\n🎉 '{name}': {added} шинэ файл нэмэгдлээ (нийт {total} бичлэг, "
          f"шинэчлэгдсэн босго {threshold:.3f})")
 
 
def load_names():
    names = []
    for folder in sorted(DATA_DIR.glob("*")):
        meta_path = folder / "meta.json"
        if not meta_path.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        templates = [extract_features(np.load(p)) for p in sorted(folder.glob("sample_*.npy"))]
        names.append({"name": meta["name"], "threshold": meta["threshold"], "templates": templates})
    return names
 
 
def list_names():
    names = load_names()
    if not names:
        print("Бүртгэлтэй нэр алга. Эхлээд: python sound_detector.py enroll <нэр>")
    for n in names:
        print(f"• {n['name']}  ({len(n['templates'])} бичлэг, босго {n['threshold']:.3f})")
 
 
def check_names(names, window, scale, verbose):
    """Нэр дуудагдсан бол нэрийг нь буцаана."""
    rms = float(np.sqrt(np.mean(window ** 2)))
    if verbose:
        print(f"\r   🎚  түвшин {rms:.3f} ", end="", flush=True)   # сонсож байгааг харуулна
    if rms < SILENCE_RMS:
        return None
    speech = trim(window)
    if len(speech) < 0.25 * SR:
        return None
    feats = extract_features(speech)
    for entry in names:
        costs = sorted(match_cost(t, feats) for t in entry["templates"])
        score = float(np.mean(costs[:2]))
        th = entry["threshold"] * scale
        if verbose:
            print(f"\r   [нэр] {entry['name']}: {score:.3f} / босго {th:.3f}")
        if score < th:
            return entry["name"], score
    return None
 
 
# =====================================================================
# 2. ЧИМЭЭ ТАНИХ (YAMNet)
# =====================================================================
class SoundClassifier:
    def __init__(self):
        os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")   # TF-ийн илүү мессежийг нууна
        import tensorflow as tf
        import tensorflow_hub as hub
 
        print("⏳ YAMNet загварыг ачаалж байна (анх удаа интернэтээс татна)...")
        self.model = hub.load("https://tfhub.dev/google/yamnet/1")
        class_map = self.model.class_map_path().numpy().decode("utf-8")
        with tf.io.gfile.GFile(class_map) as f:
            self.class_names = [row["display_name"] for row in csv.DictReader(f)]
 
        self.events = {}
        for label, cfg in SOUND_EVENTS.items():
            idx = [self.class_names.index(c) for c in cfg["classes"] if c in self.class_names]
            missing = [c for c in cfg["classes"] if c not in self.class_names]
            if missing:
                print(f"⚠️  {label}: YAMNet-д олдсонгүй -> {missing}")
            if idx:
                self.events[label] = (idx, cfg["threshold"])
 
        self.model(np.zeros(SR, dtype=np.float32))   # урьдчилан халаах
        print("✅ YAMNet бэлэн")
 
    def check(self, audio, verbose):
        scores, _, _ = self.model(audio)
        scores = scores.numpy().max(axis=0)          # бүх хэсгээс хамгийн өндөр оноо
 
        if verbose and np.sqrt(np.mean(audio ** 2)) > 0.005:
            top = np.argsort(scores)[::-1][:3]
            print("   [чимээ] " + ", ".join(f"{self.class_names[i]} {scores[i]:.2f}" for i in top))
 
        hits = []
        for label, (idx, th) in self.events.items():
            score = float(scores[idx].max())
            if score >= th:
                hits.append((label, score))
        return hits
 
 
# =====================================================================
# 3. СОНСОХ ҮНДСЭН ДАВТАЛТ
# =====================================================================
def listen(use_names, use_sounds, scale, verbose):
    names = load_names() if use_names else []
    if use_names and not names:
        print("ℹ️  Бүртгэлтэй нэр алга, зөвхөн чимээ сонсоно. (enroll <нэр> хийж нэмнэ)")
    classifier = SoundClassifier() if use_sounds else None
    if not names and classifier is None:
        print("Сонсох зүйл алга.")
        return
    if names:
        match_cost(names[0]["templates"][0], names[0]["templates"][0])  # DTW халаах
 
    q = queue.Queue()
    hop = int(HOP_SECONDS * SR)
    window = np.zeros(int(WINDOW_SECONDS * SR), dtype=np.float32)
    last_hit = {}   # зүйл бүрийн сүүлд таньсан хугацаа
    step = 0
 
    def callback(indata, frames, t, status):
        q.put(indata[:, 0].copy())
 
    def alert(label, score):
        now = time.time()
        if now - last_hit.get(label, 0) < COOLDOWN_SECONDS:
            return False
        last_hit[label] = now
        stamp = time.strftime("%H:%M:%S")
        print(f"\n🔔 [{stamp}] {label}  (оноо {score:.2f})\n\a", flush=True)
        return True
 
    watching = [f"нэр: {', '.join(n['name'] for n in names)}"] if names else []
    if classifier:
        watching.append("чимээ: " + ", ".join(classifier.events))
    print("\n👂 Сонсож байна —", " | ".join(watching))
    print("   (зогсоох: Ctrl+C)\n")
 
    with sd.InputStream(samplerate=SR, channels=1, dtype="float32", blocksize=hop, callback=callback):
        try:
            while True:
                chunk = q.get()
                window = np.concatenate([window[len(chunk):], chunk])
                step += 1
                if not q.empty():      # хоцорсон бол гүйцэх
                    continue
 
                # Чимээ: 0.5 сек тутам шалгана
                if classifier and step % 2 == 0:
                    for label, score in classifier.check(window[-int(SOUND_WINDOW * SR):], verbose):
                        alert(label, score)
 
                # Нэр: 0.25 сек тутам шалгана
                if names:
                    hit = check_names(names, window, scale, verbose)
                    if hit and alert(f"🗣  '{hit[0]}' гэж дуудлаа!", hit[1]):
                        window[:] = 0
        except KeyboardInterrupt:
            print("\nЗогслоо.")
 
 
def main():
    parser = argparse.ArgumentParser(description="Монгол нэр + гэрийн чимээ таних")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_enroll = sub.add_parser("enroll", help="нэр бүртгэх")
    p_enroll.add_argument("name")
    p_import = sub.add_parser("import", help="аудио файлуудаас (жишээ нь Chimege TTS) нэмж бүртгэх")
    p_import.add_argument("name")
    p_import.add_argument("source", help=".wav/.mp3 файлууд агуулсан хавтас")
    sub.add_parser("list", help="бүртгэлтэй нэрс")
    p_listen = sub.add_parser("listen", help="сонсож эхлэх")
    p_listen.add_argument("-v", "--verbose", action="store_true", help="оноонуудыг харуулах")
    p_listen.add_argument("-s", "--scale", type=float, default=1.0,
                          help="нэрийн босгыг үржих (их = амархан танина)")
    p_listen.add_argument("--no-names", action="store_true", help="нэр сонсохгүй")
    p_listen.add_argument("--no-sounds", action="store_true", help="чимээ сонсохгүй")
    args = parser.parse_args()
 
    if args.cmd == "enroll":
        enroll(args.name)
    elif args.cmd == "import":
        import_audio(args.name, args.source)
    elif args.cmd == "list":
        list_names()
    elif args.cmd == "listen":
        listen(not args.no_names, not args.no_sounds, args.scale, args.verbose)
 
 
if __name__ == "__main__":
    main()