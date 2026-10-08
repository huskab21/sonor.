#!/usr/bin/env python3
"""
Нэр (Батхүслэн, Хүслэн, Хүска) таних жижиг загвар сургаж, TFLite болгож гаргана.

Оролт : 1.5 секунд, 16 кГц түүхий долгион, хэлбэр [1, 24000] (float32, -1..1)
Гаралт: нэр дуудагдсан байх магадлал (0..1), хэлбэр [1, 1]

Mel-spectrogram тооцоолол загвар дотроо хийгддэг тул Flutter талд
дууг боловсруулах код бичих шаардлагагүй (YAMNet-тэй адил ашиглана).

Хэрэглээ:
  ./venv/bin/python train.py            # бүрэн сургалт
  ./venv/bin/python train.py --quick    # хурдан туршилт (код ажиллаж байгааг шалгах)

Үр дүн: model/name_detector.tflite, model/name_detector.json (босго)
"""
import argparse
import json
import os
import shutil
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import librosa
import numpy as np
import tensorflow as tf

SR = 16000
WIN = int(1.5 * SR)
N_MELS = 40
ROOT = Path(__file__).parent
DATA = ROOT / "dataset"
OUT = ROOT / "model"
VAL_VOICES = ("FEMALE3v2", "MALE3v2")   # эдгээр хоолойг сургалтад үзүүлэхгүй, шалгалтад л ашиглана

rng = np.random.default_rng(0)
MEL = tf.signal.linear_to_mel_weight_matrix(N_MELS, 257, SR, 60.0, 7600.0)


# =====================================================================
# 1. ДУУГ ЗУРАГ БОЛГОХ (сургалт, экспорт хоёрт яг ижил код ашиглана)
# =====================================================================
def frontend(wave):
    """[B, WIN] долгион -> [B, 148, 40, 1] хэвийн болгосон log-mel."""
    mag = tf.abs(tf.signal.stft(wave, frame_length=400, frame_step=160, fft_length=512))
    logmel = tf.math.log(tf.tensordot(mag, MEL, 1) + 1e-6)
    mean = tf.reduce_mean(logmel, axis=[1, 2], keepdims=True)
    std = tf.math.reduce_std(logmel, axis=[1, 2], keepdims=True)
    return ((logmel - mean) / (std + 1e-3))[..., tf.newaxis]


def featurize(waves):
    return np.concatenate([frontend(tf.constant(waves[i:i + 256])).numpy()
                           for i in range(0, len(waves), 256)])


# =====================================================================
# 2. ӨГӨГДӨЛ
# =====================================================================
def load(path):
    audio, _ = librosa.load(str(path), sr=SR, mono=True)
    return audio.astype(np.float32)


def load_trim(path):
    trimmed, _ = librosa.effects.trim(load(path), top_db=30)
    return trimmed


def load_name(path, max_seconds=1.15):
    """Нэр дуудсан бичлэгээс зөвхөн нэрийг тайрч авна.
    Орчны чимээтэй бичлэгт энгийн тайралт бүтэхгүй тул хамгийн чанга хэсгийг сонгоно
    (эс бөгөөс хоосон чимээг "нэр" гэж сургах эрсдэлтэй)."""
    audio = load(path)
    n = int(max_seconds * SR)
    for top_db in (30, 22, 16):
        trimmed, _ = librosa.effects.trim(audio, top_db=top_db)
        if len(trimmed) <= n:
            return trimmed
    start = int(np.convolve(audio ** 2, np.ones(n, dtype=np.float32), "valid").argmax())
    return audio[start:start + n]


def split_long(audio):
    """Урт бичлэгийн эхний 80%-г сургалтад, сүүлийн 20%-г шалгалтад."""
    cut = int(len(audio) * 0.8)
    return audio[:cut], audio[cut:]


def variants(clip, n):
    """Хурд, өнгийг өөрчилж өөр хүн дуудсан мэт хувилбарууд үүсгэнэ."""
    out = [clip]
    for _ in range(n):
        y = librosa.effects.time_stretch(clip, rate=float(rng.uniform(0.8, 1.25)))
        y = librosa.effects.pitch_shift(y, sr=SR, n_steps=float(rng.uniform(-2.5, 2.5)))
        out.append(y.astype(np.float32))
    return out


def crop(audio, n):
    if len(audio) < n:
        audio = np.tile(audio, n // max(len(audio), 1) + 1)
    start = int(rng.integers(0, len(audio) - n + 1))
    return audio[start:start + n].copy()


def background(bgs):
    r = rng.random()
    if bgs and r < 0.6:
        return crop(bgs[int(rng.integers(len(bgs)))], WIN) * float(rng.uniform(0.3, 1.5))
    if r < 0.9:
        return (rng.standard_normal(WIN) * 10 ** rng.uniform(-3.5, -2.0)).astype(np.float32)
    return np.zeros(WIN, dtype=np.float32)


def loud(clip):
    return clip * float(rng.uniform(0.05, 0.6) / (np.abs(clip).max() + 1e-9))


def place(clip, bgs, context=None):
    """Клипийг 1.5 сек цонхны санамсаргүй байрлалд, орчны чимээн дээр тавина."""
    w = background(bgs)
    clip = loud(clip)
    if len(clip) > WIN:
        s = (len(clip) - WIN) // 2
        clip = clip[s:s + WIN]
    off = int(rng.integers(0, WIN - len(clip) + 1))
    w[off:off + len(clip)] += clip
    # Заримдаа нэрний өмнө өөр яриа байдаг (жинхэнэ амьдрал дээр шиг)
    gap = off - SR // 10
    if context is not None and gap > SR // 4 and rng.random() < 0.3:
        c = loud(context)[-gap:]
        w[gap - len(c):gap] += c
    return np.clip(w, -1.0, 1.0)


def make_pos(src):
    pools = [p for p in (src["pos_me"], src["pos_tts"]) if p]   # хүний болон TTS хоолойг тэнцүү авна
    pool = pools[int(rng.integers(len(pools)))]
    ctx = src["neg_clips"][int(rng.integers(len(src["neg_clips"])))] if src["neg_clips"] else None
    return place(pool[int(rng.integers(len(pool)))], src["bg"], ctx)


def make_neg(src):
    r = rng.random()
    clips, speech, pos = src["neg_clips"], src["speech"], src["pos_me"] + src["pos_tts"]
    if r < 0.30 and clips:                       # төстэй нэр, үг, өгүүлбэр
        return place(clips[int(rng.integers(len(clips)))], src["bg"])
    if r < 0.50 and (speech or clips):           # хүний энгийн яриа
        if speech:
            return np.clip(loud(crop(speech[int(rng.integers(len(speech)))], WIN)) + background(src["bg"]), -1, 1)
        return place(clips[int(rng.integers(len(clips)))], src["bg"])
    if r < 0.75:                                 # зөвхөн орчны чимээ
        return np.clip(background(src["bg"]), -1, 1)
    if r < 0.90 and pos:                         # нэрийн эхний тал нь ("Бат...", "Хүс...")
        clip = pos[int(rng.integers(len(pos)))]
        n = int(len(clip) * rng.uniform(0.30, 0.45))
        return place(clip[:n], src["bg"])
    if clips:                                    # хоёр үг залгаж
        a, b = (clips[int(rng.integers(len(clips)))] for _ in range(2))
        return place(np.concatenate([loud(a), loud(b)]), src["bg"])
    return np.clip(background(src["bg"]), -1, 1)


def load_sources(n_var):
    """Сургалт, шалгалтын эх бичлэгүүдийг тусад нь ачаална (хооронд нь холихгүй)."""
    tr = {k: [] for k in ("pos_me", "pos_tts", "neg_clips", "speech", "bg")}
    va = {k: [] for k in tr}

    for p in sorted((DATA / "tts" / "pos").glob("*.wav")):
        is_val = p.stem.split("_")[-1] in VAL_VOICES
        (va if is_val else tr)["pos_tts"] += [load_name(p)] if is_val else variants(load_name(p), n_var)
    for p in sorted((DATA / "tts" / "neg").glob("*.wav")):
        is_val = p.stem.split("_")[-1] in VAL_VOICES
        (va if is_val else tr)["neg_clips"] += [load_trim(p)] if is_val else variants(load_trim(p), 1)
    for i, p in enumerate(sorted((DATA / "me" / "pos").glob("*.wav"))):
        is_val = i % 5 == 4
        (va if is_val else tr)["pos_me"] += [load_name(p)] if is_val else variants(load_name(p), n_var)
    for kind, key in (("speech", "speech"), ("background", "bg")):
        for p in sorted((DATA / "me" / kind).glob("*.wav")):
            a, b = split_long(load(p))
            tr[key].append(a)
            va[key].append(b)
    return tr, va


def build(src, n_pos, n_neg):
    waves = np.stack([make_pos(src) for _ in range(n_pos)] + [make_neg(src) for _ in range(n_neg)])
    labels = np.array([1] * n_pos + [0] * n_neg, dtype=np.float32)
    return featurize(waves.astype(np.float32)), labels


# =====================================================================
# 3. ЗАГВАР
# =====================================================================
def make_model():
    L = tf.keras.layers
    x = inp = L.Input((148, N_MELS, 1))
    for filters in (24, 48, 96, 128):
        x = L.Conv2D(filters, 3, padding="same", use_bias=False)(x)
        x = L.BatchNormalization()(x)
        x = L.ReLU()(x)
        x = L.MaxPooling2D(2)(x)
    x = L.Flatten()(x)                           # 9 цагийн алхам x 2 давтамж x 128
    x = L.Dropout(0.4)(x)
    x = L.Dense(96, activation="relu")(x)
    x = L.Dropout(0.3)(x)
    out = L.Dense(1, activation="sigmoid")(x)
    return tf.keras.Model(inp, out)


class Frontend(tf.keras.layers.Layer):
    def call(self, wave):
        return frontend(wave)


def export_tflite(model):
    """Түүхий долгион [1, WIN] авч магадлал [1, 1] буцаадаг, апп дотор ашиглах хувилбар."""
    inp = tf.keras.Input(batch_shape=(1, WIN), name="waveform")
    full = tf.keras.Model(inp, model(Frontend()(inp)))
    return tf.lite.TFLiteConverter.from_keras_model(full).convert()


def run_tflite(path, waves):
    interp = tf.lite.Interpreter(model_path=str(path))
    interp.allocate_tensors()
    i, o = interp.get_input_details()[0]["index"], interp.get_output_details()[0]["index"]
    out = []
    for w in waves:
        interp.set_tensor(i, w.astype(np.float32)[np.newaxis])
        interp.invoke()
        out.append(float(interp.get_tensor(o)[0, 0]))
    return np.array(out)


# =====================================================================
# 4. ҮНДСЭН
# =====================================================================
def main():
    parser = argparse.ArgumentParser(description="Нэр таних загвар сургах")
    parser.add_argument("--quick", action="store_true", help="цөөн өгөгдлөөр хурдан туршина")
    args = parser.parse_args()
    n_pos, n_neg, epochs, n_var = (300, 450, 2, 1) if args.quick else (8000, 14000, 40, 6)

    print("⏳ Бичлэгүүдийг ачаалж, хувилбарууд үүсгэж байна...")
    tr, va = load_sources(n_var)
    print("   сургалт : " + ", ".join(f"{k}={len(v)}" for k, v in tr.items()))
    print("   шалгалт : " + ", ".join(f"{k}={len(v)}" for k, v in va.items()))
    has_me = bool(tr["pos_me"])
    if not has_me:
        print("⚠️  dataset/me/pos хоосон байна. Зөвхөн TTS-ээр сургасан загвар жинхэнэ хоолойг муу таньдаг.")
        print("    Эхлээд: ./venv/bin/python record_me.py")

    print("⏳ Сургалтын жишээнүүдийг үүсгэж байна...")
    x_tr, y_tr = build(tr, n_pos, n_neg)
    x_va, y_va = build(va, n_pos // 5, n_neg // 5)

    model = make_model()
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
    print(f"⏳ Сургаж байна ({model.count_params()} параметр)...")
    model.fit(x_tr, y_tr, validation_data=(x_va, y_va), epochs=epochs, batch_size=64, verbose=2,
              # val_loss биш val_auc-г дагана: val_loss эхний эпохоос л өсөж, бараг сураагүй
              # эхний эпохын жинг буцааж авдаг байсан (2026-10-07, Амаржаргал нэмэхэд)
              callbacks=[tf.keras.callbacks.ReduceLROnPlateau("val_auc", mode="max", factor=0.5, patience=3, min_lr=1e-5),
                         tf.keras.callbacks.EarlyStopping("val_auc", mode="max", patience=6, restore_best_weights=True)])

    # Босго: буруу дохио 0.5%-иас хэтрэхгүй хамгийн бага утга
    p_va = model.predict(x_va, verbose=0)[:, 0]
    threshold = 0.9
    for th in np.arange(0.50, 0.991, 0.01):
        if np.mean(p_va[y_va == 0] >= th) <= 0.005:
            threshold = float(round(th, 2))
            break
    recall = float(np.mean(p_va[y_va == 1] >= threshold))
    false_alarm = float(np.mean(p_va[y_va == 0] >= threshold))
    print(f"\n📊 Шалгалт (сургалтад үзээгүй бичлэгүүд), босго {threshold:.2f}:")
    print(f"   нэрийг таньсан    : {recall:.1%}")
    print(f"   буруу дохио өгсөн : {false_alarm:.2%}")

    report = {"threshold": threshold, "recall": recall, "false_alarm": false_alarm, "trained_with_real_voice": has_me}

    def rate(key, title, waves):
        """Тухайн төрлийн бичлэгийн хэдэн хувь нь босго давсныг тайланд нэмнэ."""
        if not waves:
            return
        p = model.predict(featurize(np.stack(waves).astype(np.float32)), verbose=0)[:, 0]
        report[key] = float(np.mean(p >= threshold))
        print(f"   {title:<44}: {report[key]:6.1%}   (дундаж оноо {np.median(p):.2f})")

    print("   --- Таних ёстой (өндөр байх тусмаа сайн) ---")
    rate("real_recall", "чиний хоолой, сургалтад үзээгүй бичлэг", [place(c, va["bg"]) for c in va["pos_me"] for _ in range(20)])
    rate("tts_recall", "өөр хүний хоолой (TTS, үзээгүй)", [place(c, va["bg"]) for c in va["pos_tts"] for _ in range(8)])
    print("   --- Таних ЁСГҮЙ (бага байх тусмаа сайн) ---")
    rate("real_false_alarm", "чиний энгийн яриа", [loud(crop(sp, WIN)) for sp in va["speech"] for _ in range(300)])
    rate("similar_false_alarm", "төстэй үг, нэрс (хүслээ, Батхүлэг...)", [place(c, va["bg"]) for c in va["neg_clips"] for _ in range(6)])
    rate("background_false_alarm", "орчны чимээ", [np.clip(background(va["bg"]), -1, 1) for _ in range(300)])

    # TFLite болгож гаргах
    OUT.mkdir(exist_ok=True)
    path = OUT / "name_detector.tflite"
    path.write_bytes(export_tflite(model))

    # TFLite хувилбар нь сургасан загвартай ижил хариу өгч байгааг шалгана
    test = np.stack([make_pos(va) for _ in range(10)] + [make_neg(va) for _ in range(10)]).astype(np.float32)
    diff = float(np.abs(run_tflite(path, test) - model.predict(featurize(test), verbose=0)[:, 0]).max())
    if not diff < 1e-3:
        raise SystemExit(f"❌ TFLite хувилбар сургасан загвараас зөрж байна (зөрүү {diff}). Файлыг бүү ашигла.")
    report.update({"sample_rate": SR, "window_samples": WIN, "tflite_max_diff": diff})
    (OUT / "name_detector.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"\n✅ {path} ({path.stat().st_size / 1024:.0f} KB), TFLite-ийн зөрүү {diff:.5f}")
    print("   Микрофоноор турших: ./venv/bin/python listen_model.py -v")

    # Flutter апп руу хуулна (хурдан туршилтын загварыг хуулахгүй)
    app_assets = ROOT.parent / "mongol_sound_app" / "assets"
    if report.get("real_recall", 1.0) < 0.6:
        print(f"⚠️  Жинхэнэ хоолойг {report['real_recall']:.0%} л таньж байна (60%-иас бага). Апп руу ХУУЛСАНГҮЙ.")
    elif app_assets.exists() and not args.quick:
        for name in ("name_detector.tflite", "name_detector.json"):
            shutil.copy(OUT / name, app_assets / name)
        print(f"   Апп руу хуулагдлаа: {app_assets}")


if __name__ == "__main__":
    main()
