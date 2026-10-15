#!/usr/bin/env python3
"""
Нэрийн загварыг утсан дээрх шиг урсгалаар шалгана: 0.25 сек тутам сүүлийн 1.5 секундийг
загварт өгч, дохио өгөх дүрэм бүрээр:
  * буруу дохио: нэргүй урт бичлэгт (зурагт, радио, яриа) 1 цагт хэдэн удаа,
  * таних чадвар: жинхэнэ хоолойн шалгалтын бичлэгүүдийг ярианд шигтгэж хэдэн хувийг нь.

Хэрэглээ (sound_app дотроос):
  ./venv/bin/python eval_stream.py                       # dataset/me/speech, background, tv
  ./venv/bin/python eval_stream.py бичлэг.wav ...        # өөр урт бичлэгүүд
  ./venv/bin/python eval_stream.py --part train --mine   # бичлэгийн эхний 80%-аас буруу
                                                         # дохионы цонхнуудыг dataset/me/hard_neg/-д
  ./venv/bin/python eval_stream.py --part val            # сургалтад үзээгүй сүүлийн 20%-ийг шалгана
Апп дахь ярианы шүүлтүүрийг (YAMNet) тооцоогүй: зурагт үргэлж яриатай тул нээлттэй гэж үзнэ.
"""
import argparse
import json
import os
import warnings
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")
warnings.filterwarnings("ignore")

import librosa
import numpy as np
import soundfile as sf
import tensorflow as tf

ROOT = Path(__file__).parent
DATA = ROOT / "dataset"
MODEL = ROOT / "model"
SR = 16000
WIN = int(1.5 * SR)
HOP = SR // 4
COOLDOWN_HOPS = 10  # аппын 2.5 сек

rng = np.random.default_rng(0)


def load(path):
    audio, _ = librosa.load(str(path), sr=SR, mono=True)
    return audio.astype(np.float32)


class Model:
    def __init__(self, path):
        self.interp = tf.lite.Interpreter(model_path=str(path))
        self.interp.allocate_tensors()
        self.i = self.interp.get_input_details()[0]["index"]
        self.o = self.interp.get_output_details()[0]["index"]

    def stream(self, audio):
        """Урсгалын алхам бүрийн оноо (апп шиг: алхам бүрд сүүлийн 1.5 сек)."""
        audio = np.concatenate([np.zeros(WIN - HOP, np.float32), audio])
        out = []
        for end in range(WIN, len(audio) + 1, HOP):
            self.interp.set_tensor(self.i, audio[end - WIN:end][np.newaxis])
            self.interp.invoke()
            out.append(float(self.interp.get_tensor(self.o)[0, 0]))
        return np.array(out)


# Дохио өгөх дүрмүүд: алхам бүрийн онооноос -> тухайн алхамд дохио өгөх эсэх
def rule_current(s, th):
    """Одоогийн апп: сүүлийн 2 онооны дундаж босго давах."""
    prev = np.concatenate([[0.0], s[:-1]])
    return (s + prev) / 2 >= th


def rule_k_of_n(k, n):
    def rule(s, th):
        hit = (s >= th).astype(int)
        return np.convolve(hit, np.ones(n, int))[: len(s)] >= k
    rule.__name__ = f"{k}/{n} алхам"
    return rule


RULES = {"одоогийн (2-ын дундаж)": rule_current,
         "дараалсан 2": rule_k_of_n(2, 2),
         "4-өөс 3": rule_k_of_n(3, 4),
         "дараалсан 3": rule_k_of_n(3, 3)}


def fire_steps(fired):
    """Хүлээлтийн хугацааг (2.5 сек) тооцож дохионы алхмуудыг буцаана."""
    out, last = [], -COOLDOWN_HOPS
    for t in np.flatnonzero(fired):
        if t - last >= COOLDOWN_HOPS:
            out.append(int(t))
            last = t
    return out


def name_clips():
    """Сургалтад үзээгүй жинхэнэ хоолойн бичлэгүүд (train.py-тэй ижил: 5 тутмын 5 дахь)."""
    paths = sorted((DATA / "me" / "pos").glob("*.wav"))
    clips = []
    for i, p in enumerate(paths):
        if i % 5 != 4:
            continue
        a, _ = librosa.effects.trim(load(p), top_db=30)
        clips.append(a[: int(1.45 * SR)])
    return clips


def recall_stream(model, clips, contexts, th_list):
    """Нэрийг ярианы дунд шигтгэж, нэрийн дараах 1.5 секундэд дохио гарсан эсэх."""
    ctx = np.concatenate(contexts) if contexts else np.zeros(SR * 10, np.float32)
    parts, spans, pos = [], [], 0
    for c in clips:
        start = int(rng.integers(0, max(1, len(ctx) - 2 * SR)))
        before = ctx[start:start + 2 * SR] * 0.3  # ард нь бага зэрэг яриа
        after = ctx[start + 2 * SR:start + 4 * SR] * 0.3
        name = np.concatenate([np.zeros(SR // 4, np.float32), c])
        seg = np.concatenate([before, name, after])
        spans.append((pos + len(before), pos + len(before) + len(name) + int(1.5 * SR)))
        parts.append(seg)
        pos += len(seg)
    audio = np.concatenate(parts)
    s = model.stream(audio)
    res = {}
    for name, rule in RULES.items():
        for th in th_list:
            steps = fire_steps(rule(s, th))
            hit = sum(any(a // HOP <= t <= b // HOP for t in steps) for a, b in spans)
            res[(name, th)] = hit / len(spans)
    return res


def main():
    parser = argparse.ArgumentParser(description="Нэрийн загварыг урсгалаар шалгах")
    parser.add_argument("files", nargs="*", help="нэргүй урт бичлэгүүд (.wav)")
    parser.add_argument("--model", default=str(MODEL / "name_detector.tflite"))
    parser.add_argument("--mine", action="store_true",
                        help="буруу дохионы цонхнуудыг dataset/me/hard_neg/-д хадгална")
    parser.add_argument("--part", choices=["all", "train", "val"], default="all",
                        help="урт бичлэгийн аль хэсэг: train = эхний 80%% (train.py-тэй ижил), "
                             "val = сүүлийн 20%%")
    parser.add_argument("--mine-threshold", type=float, default=0.8,
                        help="хадгалах цонхны доод оноо (босгоос бага байж болно)")
    args = parser.parse_args()

    files = [Path(f) for f in args.files] or sorted(
        p for kind in ("speech", "background", "tv") for p in (DATA / "me" / kind).glob("*.wav"))
    if not files:
        print("Шалгах бичлэг алга.")
        return
    model = Model(args.model)
    base = json.loads((MODEL / "name_detector.json").read_text())["threshold"]
    th_list = [base, 0.95, 0.98]

    total_hours = 0.0
    alarms = {(n, th): 0 for n in RULES for th in th_list}
    contexts = []
    mined = 0
    out_dir = DATA / "me" / "hard_neg"
    for f in files:
        audio = load(f)
        cut = int(len(audio) * 0.8)
        audio = {"all": audio, "train": audio[:cut], "val": audio[cut:]}[args.part]
        hours = len(audio) / SR / 3600
        total_hours += hours
        if "speech" in f.parts or "tv" in f.parts:
            contexts.append(audio)
        s = model.stream(audio)
        line = []
        for name, rule in RULES.items():
            for th in th_list:
                n = len(fire_steps(rule(s, th)))
                alarms[(name, th)] += n
            line.append(f"{name}: {len(fire_steps(rule(s, base)))}")
        print(f"{f.name} ({len(audio) / SR / 60:.1f} мин): " + ", ".join(line))
        if args.mine:
            out_dir.mkdir(parents=True, exist_ok=True)
            last = -COOLDOWN_HOPS
            for t in np.flatnonzero(s >= args.mine_threshold):
                if t - last < 4:  # нэг үйл явдлаас 1 цонх
                    continue
                last = t
                end = (t + 1) * HOP
                clip = np.concatenate([np.zeros(WIN, np.float32), audio])[end:end + WIN]
                sf.write(out_dir / f"{f.stem}_{t:06d}.wav", clip, SR)
                mined += 1

    print(f"\nНийт {total_hours * 60:.1f} минут нэргүй бичлэг ({args.part}).")
    rec = recall_stream(model, name_clips(), contexts, th_list)
    print(f"\n{'Дүрэм':<24}{'босго':>6}{'буруу/цаг':>11}{'таних %':>9}")
    for name in RULES:
        for th in th_list:
            per_hour = alarms[(name, th)] / total_hours if total_hours else 0
            print(f"{name:<24}{th:>6.2f}{per_hour:>11.1f}{rec[(name, th)] * 100:>9.1f}")
    if args.mine:
        print(f"\n{mined} цонх {out_dir}-д хадгалагдлаа (дараа нь train.py сөрөг жишээ болгоно).")


if __name__ == "__main__":
    main()
