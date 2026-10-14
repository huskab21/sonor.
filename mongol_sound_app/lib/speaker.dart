import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// Chimege-ийн бичвэр -> яриа (TTS) үйлчилгээний токен. Кодонд бичихгүй, build хийхдээ өгнө:
///   flutter build ios --release --dart-define=CHIMEGE_TTS_TOKEN=...
/// STT-ийн токентой адил: аппын файл дотор ордог тул зөвхөн өөрийн утсан дээрх туршилтад.
const String chimegeTtsToken = String.fromEnvironment('CHIMEGE_TTS_TOKEN');

const String _ttsUrl = 'https://api.chimege.com/v1.2/synthesize';

/// Тоглуулахдаа микрофоны бичлэгийг (сонсох хөдөлгүүр) зогсоохгүй, хамт ажиллана.
final VideoPlayerOptions _mix = VideoPlayerOptions(mixWithOthers: true);

class SpeakerException implements Exception {
  const SpeakerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Урт бичвэрийг өгүүлбэр, үгийн заагаар [max] тэмдэгтээс ихгүй хэсгүүдэд хуваана.
List<String> splitForSpeech(String text, {int max = 200}) {
  final parts = <String>[];
  var rest = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  while (rest.length > max) {
    final window = rest.substring(0, max);
    // Өгүүлбэрийн төгсгөл, эс бөгөөс сүүлийн зайгаар таслана
    var cut = window.lastIndexOf(RegExp(r'[.!?…,;:]\s'));
    cut = cut > max ~/ 3 ? cut + 1 : window.lastIndexOf(' ');
    if (cut <= 0) cut = max;
    parts.add(rest.substring(0, cut).trim());
    rest = rest.substring(cut).trim();
  }
  if (rest.isNotEmpty) parts.add(rest);
  return parts;
}

/// Ижил хэлбэрийн (суваг, давтамж) хэд хэдэн WAV-ийг нэг файл болгоно.
Uint8List joinWav(List<Uint8List> parts) {
  ({int at, int length}) dataChunk(Uint8List wav) {
    final b = ByteData.sublistView(wav);
    var at = 12;
    while (at + 8 <= wav.length) {
      final id = String.fromCharCodes(wav.sublist(at, at + 4));
      final size = b.getUint32(at + 4, Endian.little);
      if (id == 'data') {
        return (at: at + 8, length: size.clamp(0, wav.length - at - 8));
      }
      at += 8 + size + (size & 1);
    }
    throw const FormatException('WAV-д data хэсэг алга');
  }

  final first = parts.first;
  final head = dataChunk(first);
  final pcm = BytesBuilder(copy: false);
  for (final p in parts) {
    final d = dataChunk(p);
    pcm.add(Uint8List.sublistView(p, d.at, d.at + d.length));
  }
  final data = pcm.toBytes();
  final out = Uint8List(head.at + data.length)
    ..setRange(0, head.at, first)
    ..setRange(head.at, head.at + data.length, data);
  final b = ByteData.sublistView(out);
  b.setUint32(4, out.length - 8, Endian.little); // RIFF хэмжээ
  b.setUint32(head.at - 4, data.length, Endian.little); // data хэмжээ
  return out;
}

/// Бичвэрийг монгол яриа болгож чангаар хэлнэ (Chimege TTS). Нэг бичвэрийг дахин хэлэхэд
/// сервер рүү дахин хандахгүй (Chimege-ийн эрх хэмнэнэ).
class Speaker {
  Speaker({http.Client? client, String? token, this.voice = 'FEMALE3v2'})
    : _client = client ?? http.Client(),
      token = token ?? chimegeTtsToken;

  final http.Client _client;
  final String token;
  final String voice;
  final Map<String, Uint8List> _cache = {};
  VideoPlayerController? _player;
  File? _file;

  bool get available => token.isNotEmpty;

  Future<Uint8List> synthesize(String text) async {
    final key = text.trim();
    final cached = _cache[key];
    if (cached != null) return cached;
    final parts = <Uint8List>[];
    for (final chunk in splitForSpeech(key)) {
      http.Response res;
      try {
        res = await _client
            .post(
              Uri.parse(_ttsUrl),
              headers: {
                'Content-Type': 'text/plain; charset=utf-8',
                'Token': token,
                'voice-id': voice,
                'speed': '1',
                'pitch': '1',
                'sample-rate': '22050',
              },
              body: utf8.encode(chunk),
            )
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        throw const SpeakerException(
          'Дуу болгож чадсангүй. Интернэт холболтоо шалгана уу.',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const SpeakerException(
          'Дуу болгох үйлчилгээний эрх буруу байна.',
        );
      }
      if (res.statusCode != 200) {
        throw SpeakerException('Дуу болгож чадсангүй (${res.statusCode}).');
      }
      parts.add(res.bodyBytes);
    }
    if (parts.isEmpty) throw const SpeakerException('Хэлэх бичвэр алга.');
    final wav = parts.length == 1 ? parts.first : joinWav(parts);
    _cache[key] = wav;
    return wav;
  }

  /// Бичвэрийг дуу болгоод утасны чанга яригчаар тоглуулна. Өмнөхийг нь зогсооно.
  Future<void> speak(String text) async {
    if (!available) {
      throw const SpeakerException('Дуу болгох үйлчилгээ холбогдоогүй байна.');
    }
    final wav = await synthesize(text);
    await _stop();
    // Аудио тоглуулагч нэмэлгүйн тулд видео тоглуулагчаар (AVPlayer) WAV тоглуулна
    final VideoPlayerController player;
    if (kIsWeb) {
      player = VideoPlayerController.networkUrl(
        Uri.dataFromBytes(wav, mimeType: 'audio/wav'),
        videoPlayerOptions: _mix,
      );
    } else {
      final file = File(
        '${Directory.systemTemp.path}/sonor_tts_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(wav, flush: true);
      _file = file;
      player = VideoPlayerController.file(file, videoPlayerOptions: _mix);
    }
    _player = player;
    try {
      await player.initialize();
      await player.setVolume(1);
      await player.play();
    } catch (_) {
      throw const SpeakerException('Дууг тоглуулж чадсангүй.');
    }
  }

  Future<void> _stop() async {
    final player = _player;
    final file = _file;
    _player = null;
    _file = null;
    await player?.dispose();
    try {
      await file?.delete();
    } catch (_) {
      // Түр файл устаагүй ч хамаагүй: систем өөрөө цэвэрлэнэ
    }
  }

  Future<void> dispose() => _stop();
}
