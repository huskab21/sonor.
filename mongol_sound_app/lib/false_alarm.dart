import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sounds.dart';
import 'transcriber.dart';

/// «Буруу» гэж тэмдэглэсэн дохионы 1.5 секундийн дууг утсанд WAV болгож хадгална.
/// Mac-аас кабелиар татаж (`xcrun devicectl device copy from ... Documents/false_alarms`)
/// нэр таних загварыг дахин сургахад «нэр биш» жишээ болгоно. Гадагш илгээхгүй.
Future<bool> saveFalseAlarmClip(Detection d) async {
  final audio = d.audio;
  if (audio == null) return false;
  try {
    final app = Directory.systemTemp.parent.path;
    final dir = Directory(
      Platform.isIOS
          ? '$app/Documents/false_alarms'
          : '$app/files/false_alarms',
    );
    await dir.create(recursive: true);
    final kind = d.isName ? 'name' : (d.id ?? 'sound');
    final stamp = d.time.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    await File('${dir.path}/${kind}_$stamp.wav').writeAsBytes(encodeWav(audio));
    return true;
  } catch (e) {
    debugPrint('FalseAlarm: $e');
    return false;
  }
}
