import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// Зүрхэлсэн (аль нэг жагсаалтад байгаа) дохионы бичлэгийг утсанд хадгалж, интернэтгүй
/// үзүүлнэ. Жагсаалтаас гарсан дохионы файл устана. Бичлэг бүр ~220 KB.
class SignCache {
  SignCache._();

  /// Утсанд хадгалагдсан дохионы дугаарууд.
  static final ValueNotifier<Set<int>> saved = ValueNotifier({});

  /// Хадгалсан бичлэгүүдийн нийт хэмжээ (байт).
  static final ValueNotifier<int> bytes = ValueNotifier(0);

  /// Хадгалах хавтас. Тестэд түр хавтсаар солино.
  @visibleForTesting
  static Future<Directory> Function() folder = _appFolder;

  static Future<Directory>? _dir;
  static bool _busy = false;
  static Map<int, String>? _pending;

  /// Аппын хавтас (`systemTemp` нь түүний `tmp`): iOS-д `Library/Application Support`
  /// (утас цэвэрлэхэд устахгүй), Android-д аппын өгөгдлийн хавтас.
  static Future<Directory> _appFolder() async {
    final app = Directory.systemTemp.parent.path;
    final dir = Directory(
      Platform.isIOS
          ? '$app/Library/Application Support/signs'
          : '$app/files/signs',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Хавтас үүсгэж чадаагүй бол дараагийн удаа дахин оролдоно.
  static Future<Directory> _folder() =>
      _dir ??= folder().catchError((Object e) {
        _dir = null;
        throw e;
      });

  static File _file(Directory dir, int id) => File('${dir.path}/$id.mp4');

  /// Хадгалсан бичлэгээс тоглуулагч. Хадгалаагүй эсвэл алдаа гарвал null: тэр үед
  /// сайтаас тоглуулна.
  static Future<VideoPlayerController?> localPlayer(int id) async {
    try {
      final f = _file(await _folder(), id);
      if (!await f.exists()) return null;
      return VideoPlayerController.file(
        f,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    } catch (e) {
      debugPrint('SignCache: $e');
      return null;
    }
  }

  /// Утсан дээрх бичлэгийг [wanted] (дугаар -> mp4 хаяг)-тай тааруулна: дутууг
  /// татаж, илүүг устгана. Интернэтгүй үед татаж чадаагүйг дараагийн удаа оролдоно.
  static Future<void> sync(
    Map<int, String> wanted, {
    http.Client? client,
  }) async {
    if (_busy) {
      _pending = wanted; // одоогийн ажил дуусахад хамгийн сүүлийнхийг хийнэ
      return;
    }
    _busy = true;
    final http.Client net = client ?? http.Client();
    try {
      final dir = await _folder();
      await for (final e in dir.list()) {
        final name = e.uri.pathSegments.last;
        final id = int.tryParse(name.split('.').first);
        if (e is File &&
            (id == null || !wanted.containsKey(id) || !name.endsWith('.mp4'))) {
          await e.delete();
        }
      }
      await _refresh(dir);
      for (final MapEntry(key: id, value: url) in wanted.entries) {
        final f = _file(dir, id);
        if (await f.exists()) continue;
        try {
          final res = await net.get(Uri.parse(Uri.encodeFull(url)));
          if (res.statusCode != 200) continue;
          // Бүрэн татагдсаны дараа л нэрийг нь өгнө: тасарсан файл тоглохгүй
          final part = File('${f.path}.part');
          await part.writeAsBytes(res.bodyBytes, flush: true);
          await part.rename(f.path);
          await _refresh(dir);
        } catch (_) {} // интернэтгүй: дараагийн удаа
      }
    } catch (e) {
      debugPrint('SignCache: $e');
    } finally {
      if (client == null) net.close();
      _busy = false;
      final next = _pending;
      _pending = null;
      if (next != null) unawaited(sync(next, client: client));
    }
  }

  static Future<void> _refresh(Directory dir) async {
    final ids = <int>{};
    var total = 0;
    await for (final e in dir.list()) {
      final name = e.uri.pathSegments.last;
      final id = int.tryParse(name.split('.').first);
      if (e is File && id != null && name.endsWith('.mp4')) {
        ids.add(id);
        total += await e.length();
      }
    }
    saved.value = ids;
    bytes.value = total;
  }
}
