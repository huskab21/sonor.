#!/usr/bin/env python3
"""
Chimege TTS-ээр нэр (Батхүслэн, Хүслэн, Хүска) таних загварын сургалтын өгөгдөл үүсгэнэ.

  dataset/tts/pos/   -> нэр өөрөө (олон хоолой, өөр аялгаар)
  dataset/tts/neg/   -> төстэй нэрс, үгс, өгүүлбэрүүд (нэр БИШ)

Хэрэглээ:
  ./venv/bin/python make_dataset.py            # дутуу файлуудыг л татна
  ./venv/bin/python make_dataset.py --dry-run  # хэдэн удаа API дуудахыг л харуулна
  ./venv/bin/python make_dataset.py --name Хүсээ   # шинэ нэр нэмж татна (44 удаа API дуудна)

Аль хэдийн татсан файлыг дахин татахгүй тул тасалдсан ч дахин ажиллуулж болно.
Хурд, өнгийн хувилбаруудыг train.py компьютер дээрээ үнэгүй үүсгэдэг тул
API-г зөвхөн өөр өөр үг, хоолой авахад зарцуулна.
"""
import argparse
import os
import shutil
import time
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv()
API_TOKEN = os.getenv("CHIMEGE_API_TOKEN", "")
BASE_URL = "https://api.chimege.com/v1.2/synthesize"

ROOT = Path(__file__).parent
OUT = ROOT / "dataset" / "tts"
OLD_VOICES = ROOT / "chimege_voices"   # өмнө нь татсан 11 файлыг дахин ашиглана

VOICES = [
    "FEMALE1", "FEMALE1v2", "FEMALE2v2", "FEMALE3v2", "FEMALE4v2", "FEMALE5v2",
    "MALE1", "MALE1v2", "MALE2v2", "MALE3v2", "MALE4v2",
]

NAMES = ["Батхүслэн", "Хүслэн", "Хүска"]   # таних нэр, хочууд

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


def positives(names):
    """Нэр бүрийг бүх хоолойгоор, өөр аялгаар."""
    return [t for n in names for t in (n, f"{n} ээ", f"{n}!", f"{n}?")]

# Төстэй сонсогддог нэрс: загвар эдгээрийг "биш" гэж ялгаж сурна (тус бүр 6 хоолой)
SIMILAR_NAMES = [
    "Батхүлэг", "Батсүх", "Батхүү", "Батхишиг", "Хүсэлт", "Хүрэл", "Хүйтэн",
    "Маска", "Батболд", "Батжаргал", "Батцэцэг", "Баттөр", "Батхуяг", "Батмөнх",
    "Бадамханд",
]

# Өдөр тутмын үгс (тус бүр 3 хоолой)
WORDS = [
    "Бат", "хүсэл", "хүслээ", "баярлалаа", "сайн байна уу", "за за", "тийм", "үгүй",
    "хүүхэд", "бүтээл", "хүлээгээрэй", "ээжээ", "ааваа", "наашаа ир", "хаана байна",
    "хоолоо ид", "битгий", "яасан бэ", "сонсож байна уу", "баяртай",
]

# Энгийн өгүүлбэрүүд (тус бүр 3 хоолой)
PHRASES = [
    "Өнөөдөр цаг агаар сайхан байна.",
    "Маргааш өглөө эрт босох хэрэгтэй.",
    "Хоол бэлэн боллоо, ирж идээрэй.",
    "Утас чинь дуугараад байна.",
    "Хаалга тогшиж байна, хэн ирсэн бэ?",
    "Би дэлгүүр ороод ирье.",
    "Чи гэрийн даалгавраа хийсэн үү?",
    "Цай уух уу, кофе уух уу?",
    "Зурагтаа жаахан чимээгүй болгооч.",
    "Гадаа их хүйтэн байна, дулаан хувцасла.",
    "Автобус хэдэн цагт ирэх вэ?",
    "Энэ номыг уншиж үзсэн үү?",
    "Ажил дээрээ оройтож магадгүй.",
    "Найз чинь утасдсан шүү.",
    "Түлхүүрээ хаана тавьсан бэ?",
    "Амралтын өдөр хөдөө явна.",
    "Бат хүслээ биелүүлэхийг хүсэж байна.",
    "Хүүхдүүд гадаа тоглож байна.",
    "Компьютерээ унтраагаад унтаарай.",
    "Миний нэрийг хэн дуудсан бэ?",
    "Одоо хэдэн цаг болж байна?",
    "Цонхоо хаагаарай, салхи орж байна.",
    "Би чамайг сонсохгүй байна.",
    "Маш их баярлалаа, сайхан амраарай.",
    "Хурал арван цагт эхэлнэ.",
]


def synthesize(text, voice_id):
    headers = {
        "Content-Type": "text/plain",
        "Token": API_TOKEN,
        "voice-id": voice_id,
        "speed": "1",
        "pitch": "1",
        "sample-rate": "22050",
    }
    r = requests.post(BASE_URL, data=text.encode("utf-8"), headers=headers, timeout=30)
    if r.status_code != 200:
        raise RuntimeError(f"HTTP {r.status_code}, Error-Code={r.headers.get('Error-Code', '?')}, "
                           f"body={r.text[:200]}")
    return r.content


def build_jobs(names):
    """(хавтас, файлын нэр, текст, хоолой) жагсаалт. Хоолойг ээлжлүүлж хуваарилна."""
    jobs = []
    for i, text in enumerate(positives(names)):
        for voice in VOICES:
            jobs.append(("pos", f"pos_{i:03d}_{voice}.wav", text, voice))

    k = 0
    for kind, texts, per_text in (("name", SIMILAR_NAMES, 6), ("word", WORDS, 3), ("phrase", PHRASES, 3)):
        for i, text in enumerate(texts):
            for _ in range(per_text):
                voice = VOICES[k % len(VOICES)]
                k += 1
                jobs.append(("neg", f"{kind}_{i:03d}_{voice}.wav", text, voice))
    return jobs


def main():
    parser = argparse.ArgumentParser(description="Chimege TTS-ээр сургалтын өгөгдөл үүсгэх")
    parser.add_argument("--dry-run", action="store_true", help="API дуудахгүй, зөвхөн тоог харуулна")
    parser.add_argument("--name", action="append", default=[], help="шинэ нэр (давтаж өгч болно)")
    args = parser.parse_args()

    # Шинэ нэрийг үргэлж жагсаалтын төгсгөлд нэмнэ: хуучин файлын дугаар өөрчлөгдөхгүй
    names = NAMES + extra_names()
    new = [n for n in args.name if n not in names]
    for n in new:
        clash = [t for t in SIMILAR_NAMES + WORDS if t.lower() == n.lower()]
        if clash:
            print(f"⚠️  '{n}' нь 'биш' гэж сургадаг үгсийн жагсаалтад байна. Эхлээд тэндээс хасах хэрэгтэй.")
            return
    if not args.dry_run:
        register_names(new)
    jobs = build_jobs(names + new)
    (OUT / "pos").mkdir(parents=True, exist_ok=True)
    (OUT / "neg").mkdir(parents=True, exist_ok=True)

    # Өмнө нь татсан "Батхүслэн" файлуудыг хуулж, API эрхээ хэмнэнэ
    for voice in VOICES:
        old, new = OLD_VOICES / f"{NAMES[0]}_{voice}.wav", OUT / "pos" / f"pos_000_{voice}.wav"
        if old.exists() and not new.exists():
            shutil.copy(old, new)

    todo = [j for j in jobs if not (OUT / j[0] / j[1]).exists()]
    print(f"Нийт {len(jobs)} файл, үүнээс {len(todo)}-г шинээр татна ({len(todo)} удаа API дуудна).")
    if args.dry_run or not todo:
        return
    if not API_TOKEN:
        print(".env файлд CHIMEGE_API_TOKEN утгыг тохируулна уу.")
        return

    done, fails = 0, 0
    for folder, fname, text, voice in todo:
        try:
            audio = synthesize(text, voice)
        except Exception as e:
            fails += 1
            print(f"❌ {fname} ({text}): {e}")
            if fails >= 5:
                print("\n5 удаа дараалан алдаа гарлаа, эрхээ дэмий үрэхгүйн тулд зогслоо.")
                break
            continue
        fails = 0
        (OUT / folder / fname).write_bytes(audio)
        done += 1
        print(f"✅ [{done}/{len(todo)}] {fname}  <- {text}")
        time.sleep(0.2)

    print(f"\nДууслаа: {done} файл татлаа. Хавтас: {OUT}")


if __name__ == "__main__":
    main()
