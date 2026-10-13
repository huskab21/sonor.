import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'glass.dart';
import 'sound_engine_stub.dart' if (dart.library.ffi) 'sound_engine.dart';
import 'sounds.dart';

const Color _green = Color(0xFF34C759);
const int _ticks = 60; // тойргийг 6 градус тутам хуваана
const Duration _memory = Duration(
  seconds: 40,
); // хэмжилт энэ хугацаанд бүдгэрнэ

/// Нэг удаа гараад больсон чимээний тэмдэглэл: юу, хэзээ, хэр чанга сонсогдсон.
class SoundFix {
  SoundFix(this.detection, this.rms);
  final Detection detection;
  final double rms; // дохионы өмнөх 1.5 секундийн хамгийн чанга түвшин
}

/// Чимээний зүг хайх туршилтын хуудас. Утсаа аажуухан эргүүлэхэд луужингийн зүг бүрд
/// сонсогдсон чимээний хүчийг тойрог дээр тэмдэглэж, хамгийн чанга зүгийг ногооноор
/// харуулна. Чимээ рүү ойртох тусам цацраг уртасна.
class FinderScreen extends StatefulWidget {
  const FinderScreen({super.key, required this.engine, this.fixes = const []});
  final SoundEngine engine;
  final List<SoundFix> fixes; // шинэ нь эхэндээ

  /// RMS түвшнийг децибелээр 0-1 болгоно (-60 дБ = 0, -10 дБ = 1).
  static double strength(double rms) =>
      ((20 * math.log(math.max(rms, 1e-5)) / math.ln10 + 60) / 50).clamp(
        0.0,
        1.0,
      );

  /// Чимээний хүчээр зайг метрээр таамаглана: 1 метрт -28 дБ (чанга дохиолол -16 дБ)
  /// сонсогдоно гэж үзээд, 6 дБ сулрах бүрд зай хоёр дахина. Утасны микрофон
  /// тохируулгагүй, чимээ бүр өөр чанга тул зөвхөн барагцаа. Нам гүм үед null.
  static double? meters(double rms, {bool loudSource = false}) {
    final db = 20 * math.log(math.max(rms, 1e-5)) / math.ln10;
    if (db < -52) return null;
    return math.pow(10, ((loudSource ? -16 : -28) - db) / 20).toDouble();
  }

  /// Зайг уншихад хялбар бичвэр болгоно.
  static String metersText(double? m) => m == null
      ? 'чимээгүй'
      : m < 1
      ? '1 м дотор'
      : m > 15
      ? '15 м-ээс хол'
      : m < 5
      ? '≈ ${(m * 2).round() / 2} м'.replaceAll('.0 ', ' ')
      : '≈ ${m.round()} м';

  @override
  State<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends State<FinderScreen> {
  static double strength(double rms) => FinderScreen.strength(rms);

  final Float64List _loudness = Float64List(_ticks); // 0-1
  final List<DateTime?> _seenAt = List.filled(_ticks, null);
  StreamSubscription<CompassEvent>? _compass;
  Timer? _demoSpin;
  double? _heading; // градус, 0 = хойд зүг
  double _now = 0; // одоогийн чимээний хүч, 0-1
  double _rms = 0; // одоогийн түвшин (зай таамаглахад)
  bool _startedEngine = false;
  String? _error;
  bool _cameraMode = false; // камерын дүрс дээр сумаар зүг заах горим
  CameraController? _camera;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    widget.engine.level.addListener(_onLevel);
    _start();
  }

  Future<void> _start() async {
    final engine = widget.engine;
    if (!engine.isListening) {
      _startedEngine = await engine.start();
      if (!_startedEngine && mounted) {
        setState(
          () => _error =
              'Микрофоны зөвшөөрөл хэрэгтэй. Утасны тохиргооноос зөвшөөрнө үү.',
        );
        return;
      }
    }
    if (engine.isDemo) {
      // Хөтчийн демо: утас аажуухан эргэж байгаа мэт
      _demoSpin = Timer.periodic(const Duration(milliseconds: 60), (_) {
        setState(() => _heading = ((_heading ?? 0) + 1.2) % 360);
      });
      return;
    }
    final events = FlutterCompass.events;
    if (events == null) {
      if (mounted) setState(() => _error = 'Энэ төхөөрөмжид луужин алга.');
      return;
    }
    _compass = events.listen((e) {
      if (mounted && e.heading != null) {
        setState(() => _heading = (e.heading! + 360) % 360);
      }
    });
  }

  /// Камерын горимыг асааж, унтраана. Арын камерыг дуугүйгээр нээнэ (микрофоныг
  /// сонсох хөдөлгүүр ашиглаж байгаа), юу ч хадгалахгүй.
  Future<void> _toggleCamera() async {
    if (_cameraMode) {
      final old = _camera;
      setState(() {
        _cameraMode = false;
        _camera = null;
      });
      await old?.dispose();
      return;
    }
    setState(() {
      _cameraMode = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || !_cameraMode) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError = 'Камер нээгдсэнгүй. Утасны тохиргооноос камерын зөвшөөрөл өгнө үү.',
        );
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    widget.engine.level.removeListener(_onLevel);
    _compass?.cancel();
    _demoSpin?.cancel();
    if (_startedEngine) widget.engine.stop();
    super.dispose();
  }

  String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _onLevel() {
    final heading = _heading;
    if (heading == null || !mounted) return;
    var v = strength(widget.engine.level.value);
    _rms = widget.engine.level.value;
    if (widget.engine.isDemo) {
      // Демо: 120 градусын зүгт чимээний эх үүсвэр байгаа мэт
      final off = (heading - 120) * math.pi / 180;
      v = 0.25 + 0.6 * math.pow(math.cos(off / 2), 6);
    }
    final i = (heading / 360 * _ticks).round() % _ticks;
    final time = DateTime.now();
    bool fresh(int t) =>
        _seenAt[t] != null && time.difference(_seenAt[t]!) < _memory;
    setState(() {
      _now = v;
      _loudness[i] = fresh(i) ? 0.6 * _loudness[i] + 0.4 * v : v;
      _seenAt[i] = time;
      // Хурдан эргэхэд алгассан хөрш зураасуудыг ижил утгаар нөхнө
      for (final n in [(i + 1) % _ticks, (i - 1 + _ticks) % _ticks]) {
        if (!fresh(n)) {
          _loudness[n] = v;
          _seenAt[n] = time;
        }
      }
    });
  }

  /// Камерын дүрс дээр зүгийн сум, барагцаа зай, сүүлд таньсан чимээг давхарлана.
  /// [turn]: чимээний зүг утасны чиглэлээс хэдэн градус зөрж байгаа; null бол
  /// луужингаар хараахан хайгаагүй.
  Widget _cameraView(BuildContext context, String guide, double? turn) {
    final camera = _camera;
    final onTarget = turn != null && turn.abs() < 15;
    final behind = turn != null && turn.abs() > 120;
    final hint = _cameraError != null
        ? _cameraError!
        : turn == null
        ? 'Эхлээд луужингаар байрандаа бүтэн эргэж зүгээ олно уу'
        : onTarget
        ? 'Яг энэ зүгт байна. Урагш алхаарай'
        : behind
        ? 'Ард талд байна. Эргэж хараарай'
        : guide;
    // Сүүлийн 30 секундэд таньсан чимээ байвал нэрийг нь харуулна
    final recent =
        widget.fixes.isNotEmpty &&
            DateTime.now().difference(widget.fixes.first.detection.time) <
                const Duration(seconds: 30)
        ? widget.fixes.first
        : null;
    final distance = FinderScreen.metersText(
      recent != null
          ? FinderScreen.meters(recent.rms, loudSource: recent.detection.urgent)
          : FinderScreen.meters(_rms),
    );
    Widget chip(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (camera != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: camera.value.previewSize?.height ?? 1,
                    height: camera.value.previewSize?.width ?? 1,
                    child: CameraPreview(camera),
                  ),
                ),
              if (turn != null)
                Center(
                  child: Transform.rotate(
                    angle: turn * math.pi / 180,
                    child: Icon(
                      Icons.navigation,
                      size: 150,
                      color: onTarget ? _green : Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 18),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Center(
                  child: chip(
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _cameraError != null
                            ? urgentAmber
                            : (onTarget ? _green : Colors.white),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Center(
                  child: chip(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          recent?.detection.icon ?? Icons.graphic_eq,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${recent?.detection.label ?? 'Чимээ'} · $distance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = inkOf(context);
    final faint = faintOf(context);
    final time = DateTime.now();
    // Хэмжилт хуучрах тусам бүдгэрнэ
    final freshness = [
      for (final seen in _seenAt)
        seen == null
            ? 0.0
            : (1 -
                      time.difference(seen).inMilliseconds /
                          _memory.inMilliseconds)
                  .clamp(0.0, 1.0),
    ];
    final covered = freshness.where((f) => f > 0).length / _ticks;
    int? best;
    for (var i = 0; i < _ticks; i++) {
      if (freshness[i] > 0 &&
          (best == null || _loudness[i] > _loudness[best])) {
        best = i;
      }
    }
    final heading = _heading;
    final ready = covered >= 0.6 && best != null && heading != null;

    String guide;
    if (_error != null) {
      guide = _error!;
    } else if (heading == null) {
      guide = 'Луужин бэлдэж байна…';
    } else if (!ready) {
      guide = 'Утсаа хэвтээ бариад байрандаа аажуухан бүтэн эргэнэ үү';
    } else {
      // Хамгийн чанга зүг одоогийн чиглэлээс хэдэн градус зөрж байгаа (-180..180)
      final diff = ((best * 360 / _ticks - heading + 540) % 360) - 180;
      guide = diff.abs() < 15
          ? 'Чимээ яг урд талд байна. Урагш алхаарай'
          : diff > 0
          ? 'Баруун тийш эргэнэ үү'
          : 'Зүүн тийш эргэнэ үү';
    }

    // Хамгийн чанга зүг утасны чиглэлээс хэдэн градус зөрж байгаа (-180..180)
    final double? turn = ready
        ? ((best * 360 / _ticks - heading + 540) % 360) - 180
        : null;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Чимээний зүг'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: _cameraMode ? 'Луужин' : 'Камераар харах',
              icon: Icon(
                _cameraMode ? Icons.explore_outlined : Icons.videocam_outlined,
              ),
              onPressed: _toggleCamera,
            ),
          ],
        ),
        body: _cameraMode
            ? _cameraView(context, guide, turn)
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: CustomPaint(
                              painter: _RingPainter(
                                loudness: _loudness,
                                freshness: freshness,
                                heading: heading ?? 0,
                                best: ready ? best : null,
                                ink: ink,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(_now * 100).round()}',
                                      style: const TextStyle(
                                        fontSize: 54,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'чимээний хүч',
                                      style: TextStyle(
                                        color: faint,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      FinderScreen.metersText(
                                        FinderScreen.meters(_rms),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'барагцаа зай',
                                      style: TextStyle(
                                        color: faint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        guide,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: _error != null
                              ? urgentAmber
                              : (ready ? _green : null),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Туршилтын боломж. Зай нь чимээний хүчээр гаргасан барагцаа таамаг: '
                        'чимээ өөрөө чанга, сул байхаас хамаарч зөрнө.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: faint,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      if (widget.fixes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 6),
                            child: Text(
                              'Гараад больсон чимээ',
                              style: TextStyle(color: faint, fontSize: 13),
                            ),
                          ),
                        ),
                        Glass(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 168),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: [
                                for (final f in widget.fixes)
                                  ListTile(
                                    dense: true,
                                    leading: Icon(
                                      f.detection.icon,
                                      color: f.detection.urgent
                                          ? urgentAmber
                                          : null,
                                    ),
                                    title: Text(f.detection.label),
                                    subtitle: Text(
                                      '${FinderScreen.metersText(FinderScreen.meters(f.rms, loudSource: f.detection.urgent))}'
                                      ' · хүч ${(FinderScreen.strength(f.rms) * 100).round()}',
                                      style: TextStyle(color: faint),
                                    ),
                                    trailing: Text(
                                      _clock(f.detection.time),
                                      style: TextStyle(color: faint),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Face ID-ийн тойрог шиг зураасууд. Дэлгэцийн дээд тал нь утасны чиглэж буй зүг.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.loudness,
    required this.freshness,
    required this.heading,
    required this.best,
    required this.ink,
  });
  final Float64List loudness;
  final List<double> freshness;
  final double heading;
  final int? best;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.shortestSide / 2;
    final inner = reach * 0.52;
    final peak = best == null ? 1.0 : math.max(loudness[best!], 0.05);

    for (var i = 0; i < _ticks; i++) {
      // Тойрог дэлхийтэй хамт "тогтож", утас эргэхэд зураасууд эсрэг тийш эргэнэ
      final angle = (i * 360 / _ticks - heading - 90) * math.pi / 180;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final seen = freshness[i] > 0;
      // Тухайн зүгт сонсогдсон чимээ чанга байх тусам зураас урт
      final length = seen ? reach * (0.06 + 0.40 * loudness[i]) : reach * 0.05;
      var near = false;
      if (best != null) {
        final gap = (i - best!).abs();
        near = math.min(gap, _ticks - gap) <= 2;
      }
      // Хамгийн чанга зүгээс бусад нь бүдэг
      final relative = seen ? math.pow(loudness[i] / peak, 3).toDouble() : 0.0;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = near ? 5 : 3.2
        ..color = near
            ? _green
            : ink.withValues(
                alpha: seen
                    ? (0.18 + 0.6 * relative) * (0.4 + 0.6 * freshness[i])
                    : 0.10,
              );
      canvas.drawLine(
        center + dir * inner,
        center + dir * (inner + length),
        paint,
      );
    }

    // Утасны чиглэж буй зүгийг заах жижиг гурвалжин (дээд талд)
    final tip = center + Offset(0, -inner + 16);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy - 9)
        ..lineTo(tip.dx - 7, tip.dy + 4)
        ..lineTo(tip.dx + 7, tip.dy + 4)
        ..close(),
      Paint()..color = ink.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}
