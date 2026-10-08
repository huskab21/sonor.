"""
Chimege API-г туршиx жишээ скрипт.

Хэрэглэх алхам:
1. console.chimege.com дээр бүртгүүлж API token авна.
2. .env файлд CHIMEGE_API_TOKEN утгыг тохируулна.
3. Terminal дээр ажиллуулна:
     python test_chimege_api.py

Энэ скрипт нэг үгийг (жишээ нь нэр) 11 өөр хоолойгоор (6 эмэгтэй, 5 эрэгтэй)
уншуулж, тус бүрийг .wav файл болгон хадгална. Ингэснээр аль хоолойнууд
хамгийн сайн сонсогдож байгааг шалгаж болно.
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()
API_TOKEN = os.getenv("CHIMEGE_API_TOKEN", "")

BASE_URL = "https://api.chimege.com/v1.2/synthesize"

# openapi.yml-д заасан бүх хоолойнууд
VOICE_IDS = [
    "FEMALE1", "FEMALE1v2", "FEMALE2v2", "FEMALE3v2", "FEMALE4v2", "FEMALE5v2",
    "MALE1", "MALE1v2", "MALE2v2", "MALE3v2", "MALE4v2",
]


def synthesize(text: str, voice_id: str, speed: float = 1, pitch: float = 1,
               sample_rate: int = 22050) -> bytes:
    """Нэг хоолойгоор текстийг аудио (.wav bytes) болгоно."""
    headers = {
        "Content-Type": "text/plain",
        "Token": API_TOKEN,
        "voice-id": voice_id,
        "speed": str(speed),
        "pitch": str(pitch),
        "sample-rate": str(sample_rate),
    }
    r = requests.post(BASE_URL, data=text.encode("utf-8"), headers=headers)

    if r.status_code != 200:
        error_code = r.headers.get("Error-Code", "?")
        raise RuntimeError(
            f"[{voice_id}] Алдаа: HTTP {r.status_code}, Error-Code={error_code}, "
            f"body={r.text[:200]}"
        )
    return r.content


def main():
    if not API_TOKEN:
        print(".env файлд CHIMEGE_API_TOKEN утгыг тохируулна уу.")
        return

    text = "Батхүслэн"  # турших нэр/үг
    out_dir = "chimege_voices"
    os.makedirs(out_dir, exist_ok=True)

    for voice_id in VOICE_IDS:
        try:
            audio = synthesize(text, voice_id)
            path = os.path.join(out_dir, f"{text}_{voice_id}.wav")
            with open(path, "wb") as f:
                f.write(audio)
            print(f"✅ {voice_id} -> {path}")
        except Exception as e:
            print(f"❌ {voice_id}: {e}")

    print(f"\nДууслаа. Үр дүнгийн файлуудыг '{out_dir}' хавтсанд шалгаарай.")


if __name__ == "__main__":
    main()
