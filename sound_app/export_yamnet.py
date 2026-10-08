import os, numpy as np
os.environ["TF_CPP_MIN_LOG_LEVEL"]="3"
import tensorflow as tf
m = tf.saved_model.load(os.path.expanduser("~/Downloads/yamnet-tensorflow2-yamnet-v1"))
@tf.function(input_signature=[tf.TensorSpec([15600], tf.float32, name="waveform")])
def f(w):
    s, e, _ = m(w)
    return {"scores": s, "embeddings": e}
conv = tf.lite.TFLiteConverter.from_concrete_functions([f.get_concrete_function()], m)
open(os.environ["OUT"], "wb").write(conv.convert())
new = tf.lite.Interpreter(os.environ["OUT"]); new.allocate_tensors()
old = tf.lite.Interpreter("../mongol_sound_app/assets/yamnet.tflite"); old.allocate_tensors()
print("in", [(d["name"], list(d["shape"])) for d in new.get_input_details()])
print("out", [(d["name"], list(d["shape"])) for d in new.get_output_details()])
import librosa
a,_ = librosa.load("dataset/me/pos/me_003.wav", sr=16000); a = np.pad(a,(0,15600))[:15600].astype(np.float32)
def run(it):
    it.set_tensor(it.get_input_details()[0]["index"], a); it.invoke()
    return {tuple(d["shape"]): it.get_tensor(d["index"]) for d in it.get_output_details()}
n = run(new); o = run(old)
s, e, _ = m(tf.constant(a))
print("scores vs old tflite maxdiff", np.abs(n[(1,521)]-o[(1,521)]).max(), "vs savedmodel", np.abs(n[(1,521)]-s.numpy()).max())
print("emb vs savedmodel maxdiff", np.abs(n[(1,1024)]-e.numpy()).max(), "nan", np.isnan(n[(1,1024)]).any(), "norm", np.linalg.norm(n[(1,1024)]))
print("size", os.path.getsize(os.environ["OUT"]))
