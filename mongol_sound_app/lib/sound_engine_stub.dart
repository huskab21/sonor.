import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'few_shot.dart';
import 'settings.dart';
import 'sounds.dart';

/// Хөтөч дээр дизайн харах зориулалттай ДЕМО хувилбар.
/// TFLite хөтөч дээр ажилладаггүй тул микрофон сонсохгүй, хуурамч дохио үүсгэнэ.
class SoundEngine {
  SoundEngine({
    required this.settings,
    required this.onDetection,
    this.onLevel,
  });

  final AppSettings settings;
  final void Function(Detection) onDetection;
  final void Function(double level)? onLevel;
  final ValueNotifier<double> level = ValueNotifier(0);

  Timer? _timer;
  int _tick = 0;
  int _next = 0;

  bool get hasNameModel => true;
  bool get isListening => _timer != null;
  bool get isDemo => true;

  Future<void> load() async {}

  Future<bool> start() async {
    _tick = 0;
    _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      _tick++;
      level.value = 0.03 + 0.03 * math.sin(_tick / 2).abs();
      onLevel?.call(level.value);
      if (_tick % 20 != 0) return;
      // 5 секунд тутам нэр, чимээг ээлжлэн "танина"
      final sounds = soundEvents
          .where((e) => settings.enabledSounds.contains(e.id))
          .toList();
      final nameTurn =
          _next % 3 == 0 && settings.nameEnabled && settings.names.isNotEmpty;
      if (nameTurn || sounds.isEmpty) {
        onDetection(
          Detection(
            Icons.record_voice_over,
            'Таны нэрийг дуудлаа',
            0.93,
            isName: true,
          ),
        );
      } else {
        final e = sounds[_next % sounds.length];
        onDetection(Detection(e.icon, e.label, 0.5, urgent: e.urgent));
      }
      _next++;
    });
    return true;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() => stop();

  Completer<void>? _sampleDone;

  void stopSample() {
    final done = _sampleDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Демо: зогсоох хүртэл "бичээд" 2 секундийн сул шуугиан буцаана.
  Future<({Float32List? clip, String? error})> recordClip({
    int maxSeconds = 15,
  }) async {
    final done = _sampleDone = Completer<void>();
    await done.future.timeout(Duration(seconds: maxSeconds), onTimeout: () {});
    final random = math.Random();
    return (
      clip: Float32List.fromList([
        for (var i = 0; i < sampleRate * 2; i++)
          0.1 * (random.nextDouble() - 0.5),
      ]),
      error: null,
    );
  }

  /// Демо: зогсоох хүртэл "бичээд" санамсаргүй embedding буцаана.
  Future<({Float32List? sample, String? error})> recordSample({
    int maxSeconds = 15,
  }) async {
    final done = _sampleDone = Completer<void>();
    await done.future.timeout(Duration(seconds: maxSeconds), onTimeout: () {});
    final random = math.Random();
    final sample = Float32List.fromList([
      for (var i = 0; i < embeddingSize; i++) random.nextDouble(),
    ]);
    normalize(sample);
    return (sample: sample, error: null);
  }
}
