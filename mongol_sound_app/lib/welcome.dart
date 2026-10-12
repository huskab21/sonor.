import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth.dart';
import 'glass.dart';
import 'screens.dart';

/// Анх нээхэд гарах танилцуулга: угтах дэлгэц, дараа нь (холбогдсон бол) и-мэйлээр нэвтрэх.
/// Нэвтрэх нь заавал биш, алгасаад үнэгүй ашиглаж болно.
class WelcomeFlow extends StatefulWidget {
  const WelcomeFlow({super.key, required this.auth, required this.onDone});
  final AuthService auth;
  final VoidCallback onDone;

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  bool _askLogin = false;

  void _afterWelcome() {
    final auth = widget.auth;
    if (auth.available && auth.email == null) {
      setState(() => _askLogin = true);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _askLogin
          ? _LoginStep(auth: widget.auth, onDone: widget.onDone)
          : _WelcomeStep(onStart: _afterWelcome),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: Center(child: HeadphoneHero())),
                const Text(
                  'Чимээг мэдэр',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Дуудлагаа бүү алд',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: faint,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sonor таны оронд сонсож, нэрийг тань дуудах болон хонх, дохиолол зэрэг '
                  'чухал чимээг дэлгэц, чичиргээгээр мэдэгдэнэ.',
                  style: TextStyle(fontSize: 16, height: 1.4, color: faint),
                ),
                const SizedBox(height: 28),
                SwipeToStart(label: 'Гулсуулж эхлэх', onDone: onStart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginStep extends StatelessWidget {
  const _LoginStep({required this.auth, required this.onDone});
  final AuthService auth;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: auth,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              children: [
                AccountCard(auth: auth),
                const SizedBox(height: 16),
                auth.email != null
                    ? FilledButton(
                        onPressed: onDone,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Үргэлжлүүлэх',
                            style: TextStyle(fontSize: 17),
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: onDone,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Нэвтрэхгүйгээр үнэгүй ашиглах',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Чихэвчний зураг: аяганд нь Sonor-ын лого, хажуугаар нь дууны долгион лугшина.
class HeadphoneHero extends StatefulWidget {
  const HeadphoneHero({super.key});

  @override
  State<HeadphoneHero> createState() => _HeadphoneHeroState();
}

class _HeadphoneHeroState extends State<HeadphoneHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final logo = w * _logoRadius * 2;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeadphonePainter(
                    _pulse,
                    isDark(context)
                        ? const Color(0xFFD9C2FF)
                        : accentOf(context),
                  ),
                ),
              ),
              Positioned(
                left: w * _cupX - logo / 2,
                top: w * _cupY - logo / 2,
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: logo,
                    height: logo,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Чихэвчний хэмжээсүүд (зургийн өргөнд харьцуулсан)
const double _cupX = 0.56, _cupY = 0.62; // аяганы төв
const double _cupRadius = 0.25;
const double _logoRadius = 0.20;

class _HeadphonePainter extends CustomPainter {
  _HeadphonePainter(this.pulse, this.ink) : super(repaint: pulse);
  final Animation<double> pulse;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w * _cupX, w * _cupY);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Дууны долгион: аяганаас гадагш тархана
    for (var i = 0; i < 4; i++) {
      final t = (pulse.value + i / 4) % 1;
      canvas.drawCircle(
        center,
        w * (_cupRadius + 0.03 + 0.30 * t),
        stroke
          ..strokeWidth = 2
          ..color = ink.withValues(alpha: 0.28 * (1 - t)),
      );
    }

    // Толгойн нум: зүүн доороос толгой дээгүүр давж, аяганы дээр ирнэ
    final bandCenter = Offset(w * 0.40, w * 0.62);
    final bandRadius = w * 0.42;
    const from = math.pi * 185 / 180, to = math.pi * 300 / 180;
    final bandPaint = stroke
      ..strokeWidth = w * 0.05
      ..color = ink.withValues(alpha: 0.9);
    canvas.drawArc(
      Rect.fromCircle(center: bandCenter, radius: bandRadius),
      from,
      to - from,
      false,
      bandPaint,
    );
    // Нумыг аягатай холбох иш
    canvas.drawLine(
      bandCenter + Offset(math.cos(to), math.sin(to)) * bandRadius,
      center + Offset(w * 0.03, -w * _cupRadius),
      bandPaint..strokeWidth = w * 0.035,
    );

    // Аяга: дүүргэсэн дугуй, дотор нь лого сууна
    canvas.drawCircle(center, w * _cupRadius, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_HeadphonePainter old) => old.ink != ink;
}

/// Гулсуулж эхлүүлэх товч. Бариулыг баруун тийш чирнэ (эсвэл дарна).
class SwipeToStart extends StatefulWidget {
  const SwipeToStart({super.key, required this.label, required this.onDone});
  final String label;
  final VoidCallback onDone;

  @override
  State<SwipeToStart> createState() => _SwipeToStartState();
}

class _SwipeToStartState extends State<SwipeToStart> {
  static const double _height = 68;
  static const double _knob = 56;
  double _dx = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onDone,
      child: LayoutBuilder(
        builder: (context, box) {
          final travel = box.maxWidth - _knob - 12;
          return Glass(
            radius: _height / 2,
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: Opacity(
                      opacity: (1 - _dx / travel * 1.5).clamp(0.0, 1.0),
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: Duration(milliseconds: _dragging ? 0 : 220),
                    curve: Curves.easeOut,
                    left: 6 + _dx,
                    child: GestureDetector(
                      onTap: widget.onDone,
                      onHorizontalDragStart: (_) =>
                          setState(() => _dragging = true),
                      onHorizontalDragUpdate: (d) => setState(
                        () => _dx = (_dx + d.delta.dx).clamp(0.0, travel),
                      ),
                      onHorizontalDragEnd: (_) {
                        final done = _dx > travel * 0.7;
                        setState(() {
                          _dragging = false;
                          _dx = done ? travel : 0;
                        });
                        if (done) widget.onDone();
                      },
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: const BoxDecoration(
                          gradient: accentGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_right,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
