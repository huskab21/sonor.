import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Аппын өнгө: гүн хар хөх дэвсгэр дээр нил ягаан өргөлт. Яаралтай дохиог шараар ялгана.
const Color urgentAmber = Color(0xFFFF9F0A);
const Color accentPurple = Color(0xFF8B3DFF);
const Color accentMagenta = Color(0xFFC13DFF);

/// Гол товч, сонгосон цэсний нил ягаан шилжилт.
const LinearGradient accentGradient = LinearGradient(
  colors: [accentMagenta, accentPurple, Color(0xFF6A2BE0)],
);

/// Өргөлтийн өнгө: бараан горимд тод, цайвар горимд гүн нил ягаан.
Color accentOf(BuildContext context) => Theme.of(context).colorScheme.primary;

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Үндсэн бичвэрийн өнгө: бараан горимд цагаан, цайвар горимд хар.
Color inkOf(BuildContext context) => Theme.of(context).colorScheme.onSurface;

/// Туслах бичвэрийн бүдэг өнгө.
Color faintOf(BuildContext context) => inkOf(context).withValues(alpha: 0.55);

/// Аппын бүх дэлгэцийн ард байх дэвсгэр: дээд талдаа нил ягаан туяатай.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.2, -0.85),
          radius: 1.25,
          colors: isDark(context)
              ? const [Color(0xFF3B1C74), Color(0xFF150F26), Color(0xFF0B0813)]
              : const [Color(0xFFFFFFFF), Color(0xFFF5F0FF), Color(0xFFE9E0FB)],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Шилэн гадаргуу: бүдэг тунгалаг дэвсгэр, гэрэлтсэн нарийн хүрээ.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.tint,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final dark = isDark(context);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(
              color: dark
                  ? const Color(0xFFB79CFF).withValues(alpha: 0.18)
                  : accentPurple.withValues(alpha: 0.14),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tint == null
                  ? [
                      dark
                          ? const Color(0xFFB79CFF).withValues(alpha: 0.13)
                          : Colors.white.withValues(alpha: 0.75),
                      dark
                          ? const Color(0xFFB79CFF).withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.5),
                    ]
                  : [tint!, tint!.withValues(alpha: 0.82)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Дэлгэцийн доор хөвөх дүрсэн цэс. Сонгосон нь нил ягаан дугуйгаар тодорно.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ink = inkOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Glass(
              radius: 34,
              padding: const EdgeInsets.all(7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (i, (icon, label)) in items.indexed)
                    Semantics(
                      button: true,
                      selected: i == index,
                      label: label,
                      child: Tooltip(
                        message: label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: i == index ? accentGradient : null,
                              boxShadow: [
                                if (i == index)
                                  BoxShadow(
                                    color: accentPurple.withValues(alpha: 0.55),
                                    blurRadius: 16,
                                  ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 24,
                              color: i == index
                                  ? Colors.white
                                  : ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Гол товч: шилэн капсул. Идэвхтэй үед нил ягаан шилжилтээр дүүрч, дууны түвшнээр
/// лугшина. Сонсож байгааг харуулахын тулд товчноос
/// долгион тархаж, дүрсний оронд микрофоны бодит түвшнийг дагасан баганууд хөдөлнө.
class LiquidButton extends StatefulWidget {
  const LiquidButton({
    super.key,
    required this.active,
    required this.level,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final double level; // 0-1
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _wave.repeat();
  }

  @override
  void didUpdateWidget(LiquidButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !_wave.isAnimating) _wave.repeat();
    if (!widget.active && _wave.isAnimating) _wave.stop();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 104.0;
    final radius = BorderRadius.circular(height / 2);
    final glow = widget.active
        ? 0.35 + 0.65 * widget.level.clamp(0.0, 1.0)
        : 0.0;
    final dark = isDark(context);
    final ink = inkOf(context);
    final content = widget.active ? Colors.white : ink;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: CustomPaint(
            painter: widget.active
                ? _RipplePainter(
                    _wave,
                    accentOf(context),
                    widget.level.clamp(0.0, 1.0),
                  )
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: height,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.55 : 0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: accentPurple.withValues(
                      alpha: (dark ? 0.75 : 0.5) * glow,
                    ),
                    blurRadius: 30 + 50 * glow,
                    spreadRadius: 2 * glow,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Шингэн дүүргэлт
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: widget.active
                                ? const [
                                    accentMagenta,
                                    accentPurple,
                                    Color(0xFF5B21D6),
                                  ]
                                : [
                                    ink.withValues(alpha: dark ? 0.16 : 0.07),
                                    ink.withValues(alpha: dark ? 0.04 : 0.02),
                                    ink.withValues(alpha: dark ? 0.09 : 0.05),
                                  ],
                          ),
                        ),
                      ),
                      // Дээд талын гэрлийн тусгал
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          height: height * 0.46,
                          margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(height / 2),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(
                                  alpha: widget.active ? 0.28 : 0.34,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Шилний ирмэг
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: widget.active
                                ? Colors.white.withValues(alpha: 0.45)
                                : accentOf(context)
                                      .withValues(alpha: dark ? 0.7 : 0.45),
                            width: 1.4,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          children: [
                            widget.active
                                ? CustomPaint(
                                    size: const Size.square(34),
                                    painter: _BarsPainter(
                                      _wave,
                                      content,
                                      widget.level.clamp(0.0, 1.0),
                                    ),
                                  )
                                : Icon(widget.icon, color: content, size: 34),
                            Expanded(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: content,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 34),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Товчноос гадагш тархах гурван долгион. Чимээ чанга байх тусам тод харагдана.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.progress, this.color, this.level)
    : super(repaint: progress);
  final Animation<double> progress;
  final Color color;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const reach = 64.0;
    for (var i = 0; i < 3; i++) {
      final t = (progress.value + i / 3) % 1;
      final grow = reach * Curves.easeOut.transform(t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).inflate(grow),
          Radius.circular(size.height / 2 + grow),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - t) * (0.14 + 0.5 * level)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.level != level || old.color != color;
}

/// Микрофоны түвшнийг дагаж өндөр нь өөрчлөгдөх таван багана.
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.progress, this.color, this.level)
    : super(repaint: progress);
  final Animation<double> progress;
  final Color color;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 5;
    final width = size.width / (bars * 2 - 1);
    final paint = Paint()..color = color;
    for (var i = 0; i < bars; i++) {
      final sway = 0.5 + 0.5 * math.sin(progress.value * 4 * math.pi + i * 1.7);
      final h = size.height * (0.16 + 0.12 * sway + 0.72 * level * sway);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(width / 2 + i * width * 2, size.height / 2),
            width: width,
            height: h,
          ),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.level != level || old.color != color;
}
