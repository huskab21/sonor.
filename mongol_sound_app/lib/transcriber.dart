import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'few_shot.dart';
import 'sounds.dart';

/// Chimege-ийн яриа -> бичвэр үйлчилгээний токен. Кодонд бичихгүй, build хийхдээ өгнө:
///   flutter build ios --release --dart-define=CHIMEGE_STT_TOKEN=...
/// Анхаар: ингэж өгсөн токен аппын файл дотор ордог тул зөвхөн өөрийн утсан дээрх туршилтад
/// тохирно. Бусдад тараах хувилбарт токеныг сервер дээр байлгаж, апп сервертэй ярина.
const String chimegeSttToken = String.fromEnvironment('CHIMEGE_STT_TOKEN');

/// 16 кГц, нэг сувгийн дууг 16 битийн WAV файл болгоно.
Uint8List encodeWav(Float32List samples, {int rate = sampleRate}) {
  final bytes = ByteData(44 + samples.length * 2);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt хэсгийн урт
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // нэг суваг
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little); // секундэд байт
  bytes.setUint16(32, 2, Endian.little); // нэг дээжийн байт
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Урт бичлэгийг [maxSeconds]-ээс хэтрэхгүй хэсгүүдэд хуваана. Үгийг дундуур нь таслахгүйн
/// тулд хэсэг бүрийн сүүлийн 4 секунд дотроос хамгийн нам гүм цэгийг олж тэнд хуваана.
List<Float32List> splitForTranscription(
  Float32List clip, {
  int maxSeconds = 14,
  int rate = sampleRate,
}) {
  final limit = maxSeconds * rate;
  final frame = rate ~/ 5; // 0.2 сек
  final parts = <Float32List>[];
  var start = 0;
  while (clip.length - start > limit) {
    var cut = start + limit;
    var quietest = double.infinity;
    for (
      var at = start + limit - 4 * rate;
      at + frame <= start + limit;
      at += frame ~/ 2
    ) {
      var energy = 0.0;
      for (var i = at; i < at + frame; i++) {
        energy += clip[i] * clip[i];
      }
      if (energy < quietest) {
        quietest = energy;
        cut = at + frame ~/ 2;
      }
    }
    parts.add(Float32List.sublistView(clip, start, cut));
    start = cut;
  }
  parts.add(Float32List.sublistView(clip, start));
  return parts;
}

/// Яриаг бичвэр болгоно. Дуу Chimege-ийн сервер рүү илгээгдэнэ (утсан дээр хийгдэхгүй).
class Transcriber {
  Transcriber({this.token = chimegeSttToken, http.Client? client})
    : _client = client ?? http.Client();
  final String token;
  final http.Client _client;

  static final Uri _url = Uri.parse('https://api.chimege.com/v1.2/transcribe');

  /// Токен байгаа эсвэл хөтчийн демо (хуурамч хариу) үед true.
  bool get available => token.isNotEmpty || kIsWeb;

  /// Амжилттай бол [text], үгүй бол хэрэглэгчид харуулах [error].
  Future<({String? text, String? error})> transcribe(Float32List clip) async {
    if (rms(clip) < quietRms / 2) {
      return (
        text: null,
        error: 'Яриа сонсогдсонгүй. Утсандаа ойртуулж ярина уу.',
      );
    }
    if (token.isEmpty) {
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        return (
          text: 'Сайн байна уу, өнөөдрийн уулзалт арван цагт эхэлнэ.',
          error: null,
        );
      }
      return (
        text: null,
        error: 'Яриа таних үйлчилгээ хараахан холбогдоогүй байна.',
      );
    }
    // Chimege нэг хүсэлтэд 15 секундээс урт дуу авдаггүй тул хэсэглэж илгээнэ
    final parts = <String>[];
    for (final chunk in splitForTranscription(clip)) {
      if (rms(chunk) < quietRms / 2) continue; // чимээгүй хэсгийг илгээхгүй
      final (:text, :error) = await _send(chunk);
      if (error != null && !error.startsWith(_noWords)) {
        return (text: null, error: error);
      }
      if (text != null) parts.add(text);
    }
    if (parts.isEmpty) {
      return (text: null, error: '$_noWords Тодорхой, ойроос ярина уу.');
    }
    return (text: parts.join(' '), error: null);
  }

  static const String _noWords = 'Үг танигдсангүй.';

  Future<({String? text, String? error})> _send(Float32List clip) async {
    try {
      final response = await _client
          .post(
            _url,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Punctuate': 'true',
              'Token': token,
            },
            body: encodeWav(clip),
          )
          .timeout(const Duration(seconds: 40));
      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      return switch (response.statusCode) {
        200 when body.isEmpty => (text: null, error: _noWords),
        200 => (text: body, error: null),
        403 => (
          text: null,
          error: 'Яриа таних үйлчилгээний токен буруу эсвэл эрх дууссан.',
        ),
        400 => (
          text: null,
          error: 'Бичлэгийг таньж чадсангүй. Дахин бичнэ үү.',
        ),
        503 => (
          text: null,
          error: 'Үйлчилгээ ачаалалтай байна. Түр хүлээгээд дахин оролдоно уу.',
        ),
        _ => (
          text: null,
          error: 'Алдаа гарлаа (${response.statusCode}). Дахин оролдоно уу.',
        ),
      };
    } catch (_) {
      return (
        text: null,
        error: 'Холбогдож чадсангүй. Интернэтээ шалгаад дахин оролдоно уу.',
      );
    }
  }
}
