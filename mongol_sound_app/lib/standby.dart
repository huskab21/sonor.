import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';
import 'sounds.dart';
import 'sign.dart';

/// Дохионы өнгө: нэр цагаан, ус цэнхэр, гал улаан, хаалга тогших бор.
/// Бусад аюултай чимээ улбар шар, үлдсэн нь цайвар шар.
Color flashColorOf(Detection d) => switch (d.mark) {
  '⚪' => Colors.white,
  '🔵' => const Color(0xFF7CC4FF),
  '🔴' => const Color(0xFFFF3B30),
  '🟤' => const Color(0xFFC89B6D),
  _ => d.urgent ? urgentAmber : const Color(0xFFFFE08A),
};

/// Дэлгэц дүүрэн өнгөт дохио: чимээний дүрс, нэр хар өнгөөр.
Widget _colorPage(Detection d) => Material(
  color: flashColorOf(d),
  child: SizedBox.expand(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(d.icon, size: 96, color: Colors.black),
          const SizedBox(height: 20),
          SText(
            d.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  ),
);

/// Апп нээлттэй үеийн дохио: шинэ чимээ танимагц аппын дэлгэцийн дээр өнгөт хуудас
/// гурван удаа анивчаад алга болно. Дарахад саад болохгүй.
class ColorFlash extends StatefulWidget {
  const ColorFlash({super.key, required this.flash});
  final Detection? flash;

  @override
  State<ColorFlash> createState() => _ColorFlashState();
}

class _ColorFlashState extends State<ColorFlash>
    with SingleTickerProviderStateMixin {
  // Секундэд 1.25 удаа: гэрэлд мэдрэмтгий хүнд аюулгүй хэмжээнд (3-аас бага)
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didUpdateWidget(ColorFlash old) {
    super.didUpdateWidget(old);
    final flash = widget.flash;
    if (flash != null && flash.time != old.flash?.time) {
      _blink.repeat(count: 3);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, _) {
          final flash = widget.flash;
          final lit = flash != null && _blink.isAnimating && _blink.value < 0.5;
          return lit ? _colorPage(flash) : const SizedBox.shrink();
        },
      ),
    );
  }
}

const MethodChannel _device = MethodChannel('sonor/device');

Future<void> _call(String method, Map<String, Object?> args) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await _device.invokeMethod<void>(method, args);
  } catch (_) {
    // Дэлгэцийн тохиргоо өөрчлөгдөөгүй ч дохио хэвээр харагдана
  }
}

/// «Хүлээх горим»: дэлгэц харанхуй, унтрахгүй. Чимээ танимагц дэлгэц бүтнээрээ
/// тухайн чимээний өнгөөр анивчина. Дэлгэцийг дарвал гарна.
class StandbyScreen extends StatefulWidget {
  const StandbyScreen({super.key, required this.flash, required this.onExit});

  final Detection? flash; // одоо харуулах дохио (байхгүй бол харанхуй)
  final VoidCallback onExit;

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with SingleTickerProviderStateMixin {
  // Секундэд 1.25 удаа: гэрэлд мэдрэмтгий хүнд аюулгүй хэмжээнд (3-аас бага)
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _call('keepAwake', {'on': true});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _apply();
  }

  @override
  void didUpdateWidget(StandbyScreen old) {
    super.didUpdateWidget(old);
    if (old.flash?.time != widget.flash?.time) _apply();
  }

  void _apply() {
    if (widget.flash == null) {
      _blink.stop();
      _call('brightness', {'value': 0.05});
    } else {
      _blink.repeat();
      _call('brightness', {'value': 1.0});
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    _call('keepAwake', {'on': false});
    _call('brightness', {'value': null});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flash = widget.flash;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onExit,
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, _) {
          final lit = flash != null && _blink.value < 0.5;
          final ink = lit ? Colors.black : Colors.white54;
          return Material(
            color: lit ? flashColorOf(flash) : Colors.black,
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      flash?.icon ?? Icons.graphic_eq,
                      size: flash == null ? 40 : 96,
                      color: ink,
                    ),
                    const SizedBox(height: 20),
                    SText(
                      flash?.label ??
                          'Сонсож байна\nГарах бол дэлгэцийг дарна уу',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: flash == null ? 15 : 34,
                        fontWeight: flash == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
