import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'sounds.dart';

/// Апп дэлгэц дээр нээлттэй биш үед (утас түгжээтэй, өөр апп руу шилжсэн)
/// таньсан чимээг мэдэгдлээр (notification) хүргэнэ.
class Notifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 0;

  /// Анх удаа дуудахад мэдэгдэл илгээх зөвшөөрөл асууна.
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (_) {
      // Мэдэгдэл ажиллахгүй байсан ч сонсох ажиллагаа үргэлжилнэ
    }
  }

  Future<void> show(Detection d) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _nextId++ % 1000,
        title: d.urgent ? '⚠️ ${d.label}' : d.label,
        body: d.isName ? 'Хэн нэгэн таныг дуудаж байна' : 'Sonor чимээ таньлаа',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: true),
          android: AndroidNotificationDetails(
            'detections',
            'Таньсан чимээ',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      // Дээрхтэй адил: мэдэгдлийн алдаа сонсох ажиллагааг зогсоохгүй
    }
  }
}
