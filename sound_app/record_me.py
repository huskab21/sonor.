#!/usr/bin/env python3
"""
Жинхэнэ хүний хоолойг сургалтын өгөгдөлд бичиж авна (TTS дангаараа хүрэлцэхгүй).

  dataset/me/pos/         -> нэр, хочоо дуудсан бичлэгүүд
  dataset/me/speech/      -> нэрийг ХЭЛЭЛГҮЙ ярьсан яриа
  dataset/me/background/  -> өрөөний чимээ (юу ч ярихгүй)
  dataset/me/tv/          -> зурагт, радио, YouTube-ийн яриа (нэр ороогүй)

Хэрэглээ:
  ./venv/bin/python record_me.py                 # гурвууланг нь дараалан бичнэ
  ./venv/bin/python record_me.py names -n 20     # зөвхөн нэр (нэр бүрийг 20 удаа)
  ./venv/bin/python record_me.py speech          # зөвхөн яриа
  ./venv/bin/python record_me.py background      # зөвхөн орчны чимээ
  ./venv/bin/python record_me.py tv --seconds 3600   # зурагтын дуу (5 минутаар хадгална)
  ./venv/bin/python record_me.py --who eej       # өөр хүн бичүүлэх үед (файлын нэрэнд орно)
  ./venv/bin/python record_me.py names --name Хүсээ -n 20   # шинэ нэр нэмж, зөвхөн түүнийг бичнэ

Дахин ажиллуулахад хуучин бичлэгийг дарахгүй, нэмж хадгална.
"""
import argparse
import time
from pathlib import Path

import librosa
import numpy as np
import sounddevice as sd
import soundfile as sf

SR = 16000
NAMES = ["Батхүслэн", "Хүслэн", "Хүска"]
DATA = Path(__file__).parent / "dataset" / "me"
CLIP_SECONDS = 2.0

EXTRA_FILE = Path(__file__).parent / "names_extra.txt"   # шинээр нэмсэн нэрс, мөр бүрд нэг


def extra_names():
    if not EXTRA_FILE.exists():
        return []
    return [l.strip() for l in EXTRA_FILE.read_text(encoding="utf-8").splitlines() if l.strip()]


def register_names(names):
    """Шинэ нэрсийг names_extra.txt-д нэмнэ (make_dataset.py, record_me.py хоёул уншина)."""
    known = NAMES + extra_names()
    new = [n for n in names if n not in known]
    if new:
        with EXTRA_FILE.open("a", encoding="utf-8") as f:
            f.writelines(n + "\n" for n in new)
    return new

# Олон янзаар дуудах тусам загвар сайн сурна
HINTS = [
    "энгийнээр", "чанга", "зөөлөн, намуухан", "холоос (2-3 метр)", "араас нь 'ээ' гэж нэмээд",
    "хурдан", "удаан, сунжруулж", "асуусан аясаар", "уурласан аясаар", "микрофоноос хажуу тийш харж",
]

READ_TEXT = """
  Өнөөдөр цаг агаар сайхан байна. Маргааш өглөө эрт босох хэрэгтэй.
  Хоол бэлэн боллоо, ирж идээрэй. Утас чинь дуугараад байна.
  Би дэлгүүр ороод ирье. Чи гэрийн даалгавраа хийсэн үү?
  Гадаа их хүйтэн байна, дулаан хувцасла. Автобус хэдэн цагт ирэх вэ?
  Түлхүүрээ хаана тавьсан бэ? Амралтын өдөр хөдөө явна.
  (Дууссан бол өөрийнхөөрөө юу ч хамаагүй үргэлжлүүлэн яриарай.)
"""


def record(seconds):
    audio = sd.rec(int(seconds * SR), samplerate=SR, channels=1, dtype="float32")
    sd.wait()
    return audio[:, 0]


def next_index(folder, who):
    idx = [int(p.stem.rsplit("_", 1)[1]) for p in folder.glob(f"{who}_*.wav")
           if p.stem.rsplit("_", 1)[1].isdigit()]
    return max(idx) + 1 if idx else 0


def record_names(who, n, names):
    folder = DATA / "pos"
    folder.mkdir(parents=True, exist_ok=True)
    idx = next_index(folder, who)
    total = n * len(names)
    print(f"\n=== 1. Нэр бүрийг {n} удаа, нийт {total} удаа дуудна ===")
    print("Мөр бүрд аль нэрийг, ямар аясаар дуудахыг зааж өгнө. Зөвхөн тэр нэрийг нэг удаа хэлнэ.")
    input("Бэлэн бол Enter дар...")

    i = 0
    while i < total:
        name = names[i % len(names)]
        hint = HINTS[(i // len(names)) % len(HINTS)]
        print(f"[{i + 1}/{total}] 🎙  '{name}' ({hint})... ", end="", flush=True)
        audio = record(CLIP_SECONDS)
        speech, _ = librosa.effects.trim(audio, top_db=25)
        if np.abs(audio).max() < 0.02 or not 0.3 <= len(speech) / SR <= 1.8:
            print("⚠️  сонсогдсонгүй, дахин")
            time.sleep(0.5)
            continue
        sf.write(folder / f"{who}_{idx:03d}.wav", audio, SR)
        print(f"✅ ({len(speech) / SR:.2f} сек)")
        idx += 1
        i += 1
        time.sleep(0.6)


def record_long(who, kind, seconds):
    folder = DATA / kind
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{who}_{next_index(folder, who):03d}.wav"
    rec = sd.rec(int(seconds * SR), samplerate=SR, channels=1, dtype="float32")
    for left in range(seconds, 0, -1):
        print(f"\r🎙  Бичиж байна... {left:3d} секунд үлдлээ ", end="", flush=True)
        time.sleep(1)
    sd.wait()
    print("\r🎙  Бичлэг дууслаа.                        ")
    audio = rec[:, 0]
    sf.write(path, audio, SR)
    print(f"✅ Хадгаллаа: {path.name} (түвшин {np.sqrt(np.mean(audio ** 2)):.3f})")


def record_speech(who, seconds):
    print(f"\n=== 2. Энгийн яриа ({seconds} сек) ===")
    print(f"{', '.join(NAMES + extra_names())} гэж ХЭЛЭХГҮЙ. Доорх текстийг чангаар унш:")
    print(READ_TEXT)
    input("Бэлэн бол Enter дар...")
    record_long(who, "speech", seconds)


def record_background(who, seconds):
    print(f"\n=== 3. Орчны чимээ ({seconds} сек) ===")
    print("Юу ч ярихгүй. Зурагт, хөгжим, гарын товчлуур зэрэг ердийн чимээ байж болно.")
    input("Бэлэн бол Enter дар...")
    record_long(who, "background", seconds)


def record_tv(who, seconds):
    """Зурагтын дууг 5 минутын хэсгүүдээр бичнэ: Ctrl+C дарвал бичсэн хэсгүүд үлдэнэ."""
    print(f"\n=== Зурагт, радио ({seconds // 60} минут) ===")
    print("Зурагт, YouTube, радиогоо ердийн чангаар асаа. Монгол яриа (мэдээ, кино, ток шоу)")
    print("байвал хамгийн сайн. Таны нэр гарахгүй байх ёстой. Ctrl+C-ээр эрт зогсооно.")
    input("Бэлэн бол Enter дар...")
    left = seconds
    try:
        while left > 0:
            part = min(300, left)
            record_long(who, "tv", part)
            left -= part
    except KeyboardInterrupt:
        sd.stop()
        print("\nЗогсоолоо (дуусаагүй сүүлийн хэсэг хадгалагдаагүй).")
    print("Дараа нь: ./venv/bin/python eval_stream.py --part train --mine && ./venv/bin/python train.py")


def main():
    parser = argparse.ArgumentParser(description="Сургалтад жинхэнэ хоолой бичих")
    parser.add_argument("what", nargs="?", default="all", choices=["all", "names", "speech", "background", "tv"])
    parser.add_argument("-n", type=int, default=20, help="нэр бүрийг хэдэн удаа дуудах")
    parser.add_argument("--seconds", type=int, default=None, help="яриа/орчны бичлэгийн урт")
    parser.add_argument("--who", default="me", help="хэн бичүүлж байгаа (файлын нэрэнд орно)")
    parser.add_argument("--name", action="append", default=[],
                        help="шинэ нэр (давтаж өгч болно); өгвөл зөвхөн эдгээрийг бичнэ")
    args = parser.parse_args()

    for n in register_names(args.name):
        print(f"Шинэ нэр бүртгэлээ: {n}")
    if args.what in ("all", "names"):
        record_names(args.who, args.n, args.name or NAMES + extra_names())
    if args.what in ("all", "speech"):
        record_speech(args.who, args.seconds or 90)
    if args.what in ("all", "background"):
        record_background(args.who, args.seconds or 30)
    if args.what == "tv":
        record_tv(args.who, args.seconds or 1800)
        return
    print("\n🎉 Боллоо. Дараа нь: ./venv/bin/python train.py")


if __name__ == "__main__":
    main()
