#!/usr/bin/env python3
"""
Сургасан загварыг (model/name_detector.tflite) микрофоноор шууд туршина.
Flutter апп яг ингэж ажиллана: 0.25 сек тутам сүүлийн 1.5 секундийг загварт өгнө.

Хэрэглээ:
  ./venv/bin/python listen_model.py -v            # магадлалыг байнга харуулна
  ./venv/bin/python listen_model.py -t 0.8        # босгыг гараар өгөх
"""
import argparse
import json
import os
import queue
import time
import warnings
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")
warnings.filterwarnings("ignore")

import numpy as np
import sounddevice as sd
import tensorflow as tf

MODEL_DIR = Path(__file__).parent / "model"
HOP_SECONDS = 0.25
COOLDOWN_SECONDS = 2.0


def main():
    parser = argparse.ArgumentParser(description="Нэр таних загварыг микрофоноор турших")
    parser.add_argument("-v", "--verbose", action="store_true", help="магадлалыг харуулах")
    parser.add_argument("-t", "--threshold", type=float, default=None, help="босго (0-1)")
    args = parser.parse_args()

    meta = json.loads((MODEL_DIR / "name_detector.json").read_text(encoding="utf-8"))
    sr, win = meta["sample_rate"], meta["window_samples"]
    threshold = args.threshold or meta["threshold"]

    interp = tf.lite.Interpreter(model_path=str(MODEL_DIR / "name_detector.tflite"))
    interp.allocate_tensors()
    i_in, i_out = interp.get_input_details()[0]["index"], interp.get_output_details()[0]["index"]

    q = queue.Queue()
    window = np.zeros(win, dtype=np.float32)
    recent = [0.0, 0.0]      # сүүлийн 2 магадлалын дундаж (ганц удаагийн үсрэлтэд хууртахгүй)
    last_hit = 0.0

    def callback(indata, frames, t, status):
        q.put(indata[:, 0].copy())

    print(f"\n👂 Сонсож байна — Батхүслэн / Хүслэн / Хүска (босго {threshold:.2f})")
    print("   (зогсоох: Ctrl+C)\n")
    with sd.InputStream(samplerate=sr, channels=1, dtype="float32",
                        blocksize=int(HOP_SECONDS * sr), callback=callback):
        try:
            while True:
                chunk = q.get()
                window = np.concatenate([window[len(chunk):], chunk])
                if not q.empty():
                    continue
                interp.set_tensor(i_in, window[np.newaxis])
                interp.invoke()
                recent = [recent[1], float(interp.get_tensor(i_out)[0, 0])]
                score = sum(recent) / 2
                if args.verbose:
                    bar = "█" * int(score * 20)
                    print(f"\r   {score:.2f} {bar:<20}", end="", flush=True)
                if score >= threshold and time.time() - last_hit > COOLDOWN_SECONDS:
                    last_hit = time.time()
                    print(f"\r🔔 [{time.strftime('%H:%M:%S')}] Таны нэрийг дуудлаа!  (магадлал {score:.2f})\a")
        except KeyboardInterrupt:
            print("\nЗогслоо.")


if __name__ == "__main__":
    main()
