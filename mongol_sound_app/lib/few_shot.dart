import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sounds.dart';

/// Хэрэглэгчийн заасан цөөн бичлэгээр чимээ таних: YAMNet-ийн embedding дээр
/// жижиг ангилагч (логистик регресс) сургана. Бүгд утсан дээр хийгдэнэ.

const int embeddingSize = 1024; // YAMNet-ийн embedding-ийн урт
const double quietRms =
    0.008; // үүнээс сул бичлэгийг "чимээ сонсогдоогүй" гэж үзнэ

double rms(Float32List x) {
  var sum = 0.0;
  for (final s in x) {
    sum += s * s;
  }
  return math.sqrt(sum / x.length);
}

/// Векторыг нэгж урттай болгоно (байран дээр нь).
void normalize(Float32List v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final scale = 1 / (math.sqrt(sum) + 1e-9);
  for (var i = 0; i < v.length; i++) {
    v[i] *= scale;
  }
}

/// Бичлэгээс чимээ хамгийн тод байгаа цонхнуудын эхлэлийг олно: хамгийн чанга
/// хэсгийн голд нэг, тэр хэвээрээ чанга байвал хоёр талд нь шилжүүлсэн хоёр.
/// Шилжүүлсэн хувилбарууд нь чимээ цонхны аль ч хэсэгт таарсан танихад тусална.
/// Урт бичлэгт (удаан үргэлжилдэг эсвэл хэд давтагдсан чимээ) бусад чанга хэсгээс
/// хоорондоо давхцахгүй [maxExtra] хүртэл цонх нэмж авна.
List<int> pickWindows(
  Float32List clip, {
  int window = yamnetSamples,
  int shift = 3200,
  int maxExtra = 6,
}) {
  final count = clip.length - window + 1;
  if (count <= 0) return const [];
  final energy = Float64List(count);
  var sum = 0.0;
  for (var i = 0; i < window; i++) {
    sum += clip[i] * clip[i];
  }
  energy[0] = sum;
  for (var s = 1; s < count; s++) {
    final out = clip[s - 1], inn = clip[s + window - 1];
    sum += inn * inn - out * out;
    energy[s] = sum;
  }
  final peak = energy.reduce(math.max);
  final floor = 0.8 * peak;
  // Хамгийн чанга цэгийг тойрсон тасралтгүй чанга хэсэг
  var first = energy.indexOf(peak), last = first;
  while (first > 0 && energy[first - 1] >= floor) {
    first--;
  }
  while (last < count - 1 && energy[last + 1] >= floor) {
    last++;
  }
  final center = (first + last) ~/ 2;
  final picked = [
    center,
    for (final s in [center - shift, center + shift])
      if (s >= 0 && s < count && energy[s] >= floor) s,
  ];

  // Бусад чанга хэсгүүд: 0.25 сек алхмаар нэр дэвшүүлж, чангаас нь эхлэн сонгоно
  final extras = <int>[];
  final candidates = [
    for (var s = 0; s < count; s += window ~/ 4)
      if (energy[s] >= 0.3 * peak) s,
  ]..sort((a, b) => energy[b].compareTo(energy[a]));
  for (final s in candidates) {
    if (extras.length == maxExtra) break;
    if ([center, ...extras].every((t) => (s - t).abs() >= window)) {
      extras.add(s);
    }
  }
  return [...picked, ...extras];
}

/// Нэг чимээний ангилагч: embedding -> 0..1 магадлал.
class SoundClassifier {
  SoundClassifier(this.weights);

  /// [embeddingSize] жин, төгсгөлд нь чөлөөт гишүүн.
  final Float32List weights;

  double score(Float32List embedding) {
    var z = weights[embeddingSize].toDouble();
    for (var i = 0; i < embeddingSize; i++) {
      z += weights[i] * embedding[i];
    }
    return 1 / (1 + math.exp(-z));
  }
}

/// [positives], [negatives] нь нэгж урттай embedding-үүдийг дараалуулсан жагсаалт.
/// Цөөн эерэг жишээг олон сөрөгтэй тэнцүүлэхийн тулд жинлэнэ.
SoundClassifier trainClassifier(
  Float32List positives,
  Float32List negatives, {
  int steps = 300,
  double rate = 0.5,
  double l2 = 1e-3,
}) {
  const d = embeddingSize;
  final nPos = positives.length ~/ d, nNeg = negatives.length ~/ d;
  final posWeight = nNeg / nPos;
  final total = 2.0 * nNeg;
  final w = Float64List(d), grad = Float64List(d);
  var b = 0.0;

  for (var step = 0; step < steps; step++) {
    grad.fillRange(0, d, 0);
    var gradB = 0.0;
    for (var row = 0; row < nPos + nNeg; row++) {
      final isPos = row < nPos;
      final x = isPos ? positives : negatives;
      final at = (isPos ? row : row - nPos) * d;
      var z = b;
      for (var i = 0; i < d; i++) {
        z += w[i] * x[at + i];
      }
      final p = 1 / (1 + math.exp(-z));
      final g = isPos ? (p - 1) * posWeight : p;
      for (var i = 0; i < d; i++) {
        grad[i] += g * x[at + i];
      }
      gradB += g;
    }
    for (var i = 0; i < d; i++) {
      w[i] -= rate * (grad[i] / total + l2 * w[i]);
    }
    b -= rate * gradB / total;
  }
  return SoundClassifier(
    Float32List(d + 1)
      ..setRange(0, d, w)
      ..[d] = b,
  );
}

/// Заасан чимээ бүрд ангилагч сургана. Бусад чимээний бичлэг нь сөрөг жишээ болно
/// (хоёр өөр чимээг хооронд нь андуурахгүйн тулд). `compute`-ээр дуудахад зориулсан.
Map<String, Float32List> trainAll(
  (Map<String, List<Float32List>> samples, Float32List bank) input,
) {
  final (samples, bank) = input;
  Float32List join(Iterable<Float32List> parts) {
    final b = BytesBuilder(copy: false);
    for (final p in parts) {
      b.add(p.buffer.asUint8List(p.offsetInBytes, p.lengthInBytes));
    }
    return Float32List.sublistView(b.toBytes());
  }

  return {
    for (final MapEntry(key: id, value: recordings) in samples.entries)
      if (recordings.isNotEmpty)
        id: trainClassifier(
          join(recordings),
          join([
            bank,
            for (final other in samples.entries)
              if (other.key != id) ...other.value,
          ]),
        ).weights,
  };
}

String encodeFloats(Float32List v) =>
    base64Encode(v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes));

Float32List decodeFloats(String s) {
  final bytes = base64Decode(s);
  return bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.length ~/ 4);
}
