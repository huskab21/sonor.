import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'few_shot.dart';
import 'settings.dart';
import 'sounds.dart';

/// Микрофоноос дуу авч, YAMNet (чимээ) болон нэр таних загварт өгнө.
class SoundEngine {
  SoundEngine({
    required this.settings,
    required this.onDetection,
    this.onLevel,
  });

  final AppSettings settings;
  final void Function(Detection) onDetection;
  final void Function(double level)? onLevel;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;

  Interpreter? _yamnet;
  int _scoresOutput = 0;
  int? _embeddingOutput;
  Interpreter? _nameModel;
  double _nameThreshold = 0.8;
  final List<List<int>> _eventClassIndices = [];
  final List<int> _speechIndices = [];
  static const double _speechGate = 0.3;
  int _lastSpeechStep = -100;
  final Map<int, String> _describedIndices =
      {}; // ангиллын индекс -> монгол нэр

  /// Микрофоны одоогийн түвшин (RMS), 0.25 сек тутам шинэчлэгдэнэ.
  final ValueNotifier<double> level = ValueNotifier(0);
  int _loudHops = 0;
  static const double _loudRms = 0.1;
  static const int _loudHopsNeeded = 20; // 5 секунд тасралтгүй

  // Сүүлийн 1.5 секундийн дууг тойрог буферт хадгална
  final Float32List _ring = Float32List(nameSamples);
  final Float32List _yamnetInput = Float32List(yamnetSamples);
  final Float32List _nameInput = Float32List(nameSamples);
  int _pos = 0;
  int _sinceHop = 0;
  double _hopEnergy = 0;
  int _step = 0;
  int? _carry; // хоёр хэсэгт хуваагдсан 16 бит дээжийн эхний байт
  double _prevNameScore = 0;
  final Map<String, DateTime> _lastHit = {};
  final SustainTracker _sustain = SustainTracker();
  double _rawLevel = 0; // YAMNet-ийн цонхны өсгөхөөс өмнөх түвшин

  // Хэрэглэгчийн заасан чимээ: YAMNet-ийн embedding дээр сургасан жижиг ангилагчид
  Float32List _negativeBank = Float32List(0);
  Map<String, SoundClassifier> _classifiers = {};
  final Map<String, double> _prevCustomScore = {};
  final Float32List _embedding = Float32List(embeddingSize);
  int _trainedRevision = -1;
  bool _training = false;

  // Заах бичлэг авч байх үед дээжийг энд цуглуулна
  Float32List? _capture;
  int _capturePos = 0;
  Completer<void>? _captureDone;

  bool get hasNameModel => _nameModel != null;
  bool get isListening => _subscription != null;
  bool get isDemo => false;

  static const double _silenceRms =
      0.002; // үүнээс нам гүм үед заасан чимээг шалгахгүй

  Future<void> load() async {
    final yamnet = await Interpreter.fromAsset('assets/yamnet.tflite')
      ..allocateTensors();
    // Загвар хоёр гаралттай: 521 ангиллын оноо ба 1024 урттай embedding
    final outputs = yamnet.getOutputTensors();
    for (var i = 0; i < outputs.length; i++) {
      if (outputs[i].shape.last == embeddingSize) _embeddingOutput = i;
      if (outputs[i].shape.last == 521) _scoresOutput = i;
    }
    _yamnet = yamnet;

    final classNames = parseClassMap(
      await rootBundle.loadString('assets/yamnet_class_map.csv'),
    );
    _eventClassIndices
      ..clear()
      ..addAll(
        soundEvents.map(
          (e) =>
              e.classes.map(classNames.indexOf).where((i) => i >= 0).toList(),
        ),
      );

    _speechIndices
      ..clear()
      ..addAll(speechClasses.map(classNames.indexOf).where((i) => i >= 0));
    _describedIndices.clear();
    for (final MapEntry(key: name, value: label) in describedClasses.entries) {
      final i = classNames.indexOf(name);
      if (i >= 0) _describedIndices[i] = label;
    }

    // Нэр таних загвар нь сонголттой: Python дээр сургаад assets руу хуулсны дараа идэвхжинэ
    try {
      _nameModel = await Interpreter.fromAsset('assets/name_detector.tflite')
        ..allocateTensors();
      final meta = jsonDecode(
        await rootBundle.loadString('assets/name_detector.json'),
      );
      _nameThreshold = (meta['threshold'] as num).toDouble();
    } catch (_) {
      // Файл байхгүй бол зөвхөн чимээ танина; json байхгүй бол анхны босгыг ашиглана
    }

    if (_embeddingOutput != null) {
      final bank = await rootBundle.load('assets/negative_bank.bin');
      _negativeBank = Float32List.sublistView(bank).sublist(0);
      settings.addListener(_retrain);
      await _retrain();
    }
  }

  /// Заасан бичлэг өөрчлөгдсөн бол ангилагчдыг дахин сургана (тусдаа isolate дээр).
  Future<void> _retrain() async {
    if (_training) return;
    _training = true;
    try {
      while (_trainedRevision != settings.samplesRevision) {
        final revision = settings.samplesRevision;
        final weights = settings.samples.isEmpty
            ? const <String, Float32List>{}
            : await compute(trainAll, (settings.samples, _negativeBank));
        _classifiers = weights.map((id, w) => MapEntry(id, SoundClassifier(w)));
        _prevCustomScore.clear();
        _trainedRevision = revision;
      }
    } finally {
      _training = false;
    }
  }

  /// Чимээ заах бичлэг: [stopSample] дуудах хүртэл (дээд тал нь [maxSeconds]) сонсоод
  /// чимээтэй хэсгүүдийн embedding-ийг буцаана. Дуу өөрөө хадгалагдахгүй.
  /// Амжилтгүй бол шалтгааныг [error]-т өгнө.
  Future<({Float32List? sample, String? error})> recordSample({
    int maxSeconds = 15,
  }) async {
    final yamnet = _yamnet;
    if (yamnet == null || _embeddingOutput == null) {
      return (sample: null, error: 'Одоогоор бичих боломжгүй байна.');
    }
    final (:clip, :error) = await recordClip(maxSeconds: maxSeconds);
    if (clip == null) return (sample: null, error: error);

    final embeddings = BytesBuilder();
    for (final at in pickWindows(clip)) {
      final window = Float32List.sublistView(clip, at, at + yamnetSamples);
      if (rms(window) < quietRms) continue;
      _yamnetInput.setAll(0, window);
      normalizeLevel(_yamnetInput); // таних үеийнхтэй ижил түвшинд
      _invokeYamnet(yamnet);
      embeddings.add(_embedding.buffer.asUint8List());
    }
    if (embeddings.isEmpty) {
      return (
        sample: null,
        error: 'Чимээ сонсогдсонгүй. Утсандаа ойртуулаад дахин бичнэ үү.',
      );
    }
    return (sample: Float32List.sublistView(embeddings.toBytes()), error: null);
  }

  /// [stopSample] дуудах хүртэл (дээд тал нь [maxSeconds]) микрофоноос бичиж, 16 кГц дууг
  /// буцаана. Бичиж байх үед чимээ, нэрийн дохио түр зогсоно.
  Future<({Float32List? clip, String? error})> recordClip({
    int maxSeconds = 15,
  }) async {
    if (_capture != null) {
      return (clip: null, error: 'Одоогоор бичих боломжгүй байна.');
    }
    final wasListening = isListening;
    if (!wasListening && !await start()) {
      return (
        clip: null,
        error:
            'Микрофоны зөвшөөрөл хэрэгтэй. Утасны тохиргооноос зөвшөөрнө үү.',
      );
    }
    // Эхний 0.3 секундийг (товч дарах чимээ) хаяна
    const lead = sampleRate * 3 ~/ 10;
    final done = _captureDone = Completer<void>();
    _capturePos = 0;
    final capture = _capture = Float32List(lead + maxSeconds * sampleRate);
    await done.future.timeout(
      Duration(seconds: maxSeconds + 3),
      onTimeout: () {},
    );
    final end = _capturePos;
    _capture = null;
    if (!wasListening) await stop();
    if (end - lead < yamnetSamples) {
      return (
        clip: null,
        error: 'Бичлэг хэт богино байна. Дор хаяж 1 секунд бичнэ үү.',
      );
    }
    return (clip: Float32List.sublistView(capture, lead, end), error: null);
  }

  /// Явагдаж буй заах бичлэгийг дуусгана.
  void stopSample() {
    final done = _captureDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// [_yamnetInput]-ийг загварт өгч, нэгж урттай embedding-ийг [_embedding]-д бичнэ.
  /// Ангиллын оноог буцаана.
  Float32List _invokeYamnet(Interpreter yamnet) {
    yamnet.getInputTensor(0).data = _yamnetInput.buffer.asUint8List();
    yamnet.invoke();
    final e = _embeddingOutput;
    if (e != null) {
      _embedding.setAll(
        0,
        Float32List.sublistView(yamnet.getOutputTensor(e).data),
      );
      normalize(_embedding);
    }
    return Float32List.sublistView(yamnet.getOutputTensor(_scoresOutput).data);
  }

  /// Микрофоны зөвшөөрөл аваад сонсож эхэлнэ. Зөвшөөрөөгүй бол false.
  Future<bool> start() async {
    if (isListening) return true;
    if (!await _recorder.hasPermission()) return false;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // iOS: бичиж байх үед чичиргээг зөвшөөрнө (анхдагчаар хаалттай байдаг)
        iosConfig: IosRecordConfig(
          allowHapticsAndSystemSoundsDuringRecording: true,
        ),
      ),
    );
    _subscription = stream.listen(_onAudio);
    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _sustain.clear();
    await _recorder.stop();
    _ring.fillRange(0, _ring.length, 0);
    _sinceHop = 0;
    _hopEnergy = 0;
    _carry = null;
    _prevNameScore = 0;
    _prevCustomScore.clear();
    _loudHops = 0;
    _lastSpeechStep = -100;
    level.value = 0;
  }

  Future<void> dispose() async {
    settings.removeListener(_retrain);
    await stop();
    await _recorder.dispose();
    _yamnet?.close();
    _nameModel?.close();
  }

  void _onAudio(Uint8List bytes) {
    var data = bytes;
    if (_carry != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = _carry!
        ..setRange(1, bytes.length + 1, bytes);
      _carry = null;
    }
    if (data.length.isOdd) _carry = data.last;

    final samples = ByteData.sublistView(data);
    for (var i = 0; i < data.length ~/ 2; i++) {
      final s = samples.getInt16(i * 2, Endian.little) / 32768.0;
      _ring[_pos] = s;
      _pos = (_pos + 1) % nameSamples;
      _hopEnergy += s * s;
      final capture = _capture;
      if (capture != null && _capturePos < capture.length) {
        capture[_capturePos++] = s;
        if (_capturePos == capture.length) stopSample();
      }
      if (++_sinceHop >= hopSamples) {
        final hopLevel = math.sqrt(_hopEnergy / hopSamples);
        level.value = hopLevel;
        onLevel?.call(hopLevel);
        _checkLoud(hopLevel);
        _sinceHop = 0;
        _hopEnergy = 0;
        _analyze();
      }
    }
  }

  /// Тойрог буферээс хамгийн сүүлийн [out.length] дээжийг дарааллаар нь хуулна.
  void _latest(Float32List out) {
    var p = (_pos - out.length) % nameSamples;
    for (var i = 0; i < out.length; i++) {
      out[i] = _ring[p];
      if (++p == nameSamples) p = 0;
    }
  }

  Float32List _run(Interpreter interpreter, Float32List input) {
    interpreter.getInputTensor(0).data = input.buffer.asUint8List();
    interpreter.invoke();
    return Float32List.sublistView(interpreter.getOutputTensor(0).data);
  }

  /// Чанга чимээ 5 секунд тасралтгүй үргэлжилбэл дохио өгнө.
  void _checkLoud(double hopLevel) {
    if (_capture != null || hopLevel < _loudRms * settings.thresholdScale) {
      _loudHops = 0;
      return;
    }
    if (++_loudHops < _loudHopsNeeded) return;
    if (!settings.enabledSounds.contains(loudSoundId)) return;
    final event = soundEvents.firstWhere((e) => e.id == loudSoundId);
    _alert(Detection(event.icon, event.label, hopLevel), wait: quietCooldown);
  }

  void _analyze() {
    if (_capture != null) return; // заах бичлэгийн үеэр дохио өгөхгүй
    _step++;

    // Бэлэн чимээ: 0.5 сек тутам. Заасан чимээ байвал 0.25 сек тутам шалгана.
    final yamnet = _yamnet;
    final classifiers = _classifiers;
    Float32List? scores;
    if (yamnet != null && (_step.isEven || classifiers.isNotEmpty)) {
      _latest(_yamnetInput);
      // Холын сул чимээг загварт өгөхөөс өмнө өсгөнө; нам гүмийн шалгалтууд
      // өсгөхөөс өмнөх түвшнээр хийгдэнэ
      _rawLevel = rms(_yamnetInput);
      normalizeLevel(_yamnetInput);
      scores = _invokeYamnet(yamnet);
      for (final i in _speechIndices) {
        if (scores[i] >= _speechGate) _lastSpeechStep = _step;
      }
    }

    // Нэр: 0.25 сек тутам. Сүүлийн 2 онооны дунджийг авч ганц удаагийн үсрэлтэд хууртахгүй.
    // Нэрийн загвар сирен зэрэг хүний яриа биш чимээнд хууртдаг тул YAMNet сүүлийн
    // 1.5 секундэд яриа сонссон үед л дохио өгнө.
    final nameModel = _nameModel;
    if (nameModel != null &&
        settings.nameEnabled &&
        settings.names.isNotEmpty) {
      _latest(_nameInput);
      final score = _run(nameModel, _nameInput)[0];
      final smoothed = (score + _prevNameScore) / 2;
      _prevNameScore = score;
      final heardSpeech = yamnet == null || _step - _lastSpeechStep <= 6;
      if (heardSpeech && smoothed >= settings.nameThreshold(_nameThreshold)) {
        _alert(
          Detection(
            Icons.record_voice_over,
            'Таны нэрийг дуудлаа',
            smoothed,
            isName: true,
            mark: '⚪',
          ),
        );
      }
    }

    if (scores == null) return;
    if (_step.isEven) {
      var fired = false;
      for (var e = 0; e < soundEvents.length; e++) {
        final event = soundEvents[e];
        if (!settings.enabledSounds.contains(event.id)) continue;
        var best = 0.0;
        for (final i in _eventClassIndices[e]) {
          if (scores[i] > best) best = scores[i];
        }
        final threshold = event.threshold * settings.thresholdScale;
        // Тасралтгүй чимээ: сул оноо 3 секунд тогтвол мөн дохио өгнө
        final steady =
            event.sustained &&
            _sustain.add(
              event.id,
              _rawLevel >= _silenceRms && best >= threshold * sustainedScale,
            );
        if (best >= threshold || steady) {
          if (steady) _sustain.reset(event.id);
          fired = true;
          _alert(
            Detection(
              event.icon,
              event.label,
              best,
              urgent: event.urgent,
              mark: event.mark,
            ),
          );
        }
      }
      if (!fired && settings.describeOthers) _describe(scores);
    }

    // Заасан чимээ: дараалсан хоёр цонх босго давбал л дохио өгнө (буруу дохиог бууруулна)
    if (classifiers.isEmpty) return;
    if (_rawLevel < _silenceRms) {
      _prevCustomScore.clear();
      return;
    }
    final threshold = settings.customThreshold;
    for (final MapEntry(key: id, value: classifier) in classifiers.entries) {
      if (!settings.enabledSounds.contains(id)) continue;
      final score = classifier.score(_embedding);
      final prev = _prevCustomScore[id] ?? 0;
      _prevCustomScore[id] = score;
      if (score < threshold || prev < threshold) continue;
      final event = soundEvents.where((e) => e.id == id).firstOrNull;
      if (event != null) {
        _alert(
          Detection(
            event.icon,
            event.label,
            score,
            urgent: event.urgent,
            mark: event.mark,
          ),
        );
        continue;
      }
      final custom = settings.customSounds.where((c) => c.id == id).firstOrNull;
      if (custom != null) {
        _alert(Detection(customSoundIcon, custom.label, score));
      }
    }
  }

  /// Каталогт байхгүй чимээг "... шиг чимээ" гэж түүхэнд тэмдэглэнэ.
  void _describe(Float32List scores) {
    if (_rawLevel < quietRms) return;
    String? label;
    var best = describeThreshold;
    for (final MapEntry(key: i, value: name) in _describedIndices.entries) {
      if (scores[i] >= best) {
        best = scores[i];
        label = name;
      }
    }
    if (label == null) return;
    _alert(
      Detection(Icons.graphic_eq, '$label шиг чимээ', best, guess: true),
      wait: quietCooldown,
    );
  }

  void _alert(Detection d, {Duration wait = cooldown}) {
    final last = _lastHit[d.label];
    if (last != null && d.time.difference(last) < wait) return;
    _lastHit[d.label] = d.time;
    onDetection(d);
  }
}
