import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// Хөтчийн демо: файл хадгалах боломжгүй тул бичлэгийг үргэлж сайтаас тоглуулна.
class SignCache {
  SignCache._();

  static final ValueNotifier<Set<int>> saved = ValueNotifier({});
  static final ValueNotifier<int> bytes = ValueNotifier(0);

  static Future<VideoPlayerController?> localPlayer(int id) async => null;

  static Future<void> sync(
    Map<int, String> wanted, {
    http.Client? client,
  }) async {}
}
