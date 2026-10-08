import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'auth.dart';
import 'finder.dart';
import 'glass.dart';
import 'notifier.dart';
import 'screens.dart';
import 'settings.dart';
import 'sound_engine_stub.dart' if (dart.library.ffi) 'sound_engine.dart';
import 'sounds.dart';
import 'welcome.dart';
import 'workspace.dart';

void main() {
  runApp(const MongolSoundApp());
}

class MongolSoundApp extends StatefulWidget {
  const MongolSoundApp({super.key});

  @override
  State<MongolSoundApp> createState() => _MongolSoundAppState();
}

class _MongolSoundAppState extends State<MongolSoundApp> {
  final AppSettings _settings = AppSettings();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    // Нэвтрэлт заавал биш: холбогдож чадаагүй ч апп хэвийн ажиллана
    _auth.init().catchError((_) {});
    _settings.load();
  }

  /// Хар, цагаан хоёр өнгөтэй загвар.
  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? Colors.white : Colors.black;
    final paper = dark ? Colors.black : Colors.white;
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: Colors.grey,
            brightness: brightness,
            dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
          ).copyWith(
            primary: ink,
            onPrimary: paper,
            surface: paper,
            onSurface: ink,
          ),
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sonor',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _settings.themeMode,
        home: !_settings.loaded
            ? const Backdrop(child: SizedBox.expand())
            : !_settings.onboarded
            ? WelcomeFlow(auth: _auth, onDone: _settings.setOnboarded)
            : SoundDetectorScreen(settings: _settings, auth: _auth),
      ),
    );
  }
}

class SoundDetectorScreen extends StatefulWidget {
  const SoundDetectorScreen({
    super.key,
    required this.settings,
    required this.auth,
  });
  final AppSettings settings;
  final AuthService auth;

  @override
  State<SoundDetectorScreen> createState() => _SoundDetectorScreenState();
}

class _SoundDetectorScreenState extends State<SoundDetectorScreen>
    with WidgetsBindingObserver {
  late final AppSettings _settings = widget.settings;
  final Notifier _notifier = Notifier();
  bool _inForeground = true;
  int _tab = 0; // доод цэсний сонгосон хуудас
  final List<WorkspaceMessage> _workspace = []; // Workspace хуудасны яриа
  late final SoundEngine _engine = SoundEngine(
    settings: _settings,
    onDetection: _onDetection,
    onLevel: _onLevel,
  );
  final List<Detection> _history = [];
  String? _error;
  bool _ready = false;
  bool _listening = false;
  double _level = 0;
  Detection? _flash; // хэдэн секунд том харуулах сүүлийн дохио
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _loadModel() async {
    try {
      await _settings.load();
      await _engine.load();
      setState(() => _ready = true);
    } catch (e) {
      setState(() => _error = 'Загвар ачааллахад алдаа гарлаа: $e');
    }
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _engine.stop();
      setState(() {
        _listening = false;
        _level = 0;
      });
      return;
    }
    try {
      final ok = await _engine.start();
      if (ok) await _notifier.init();
      setState(() {
        _listening = ok;
        _error = ok
            ? null
            : 'Микрофоны зөвшөөрөл хэрэгтэй. Утасны тохиргооноос зөвшөөрнө үү.';
      });
    } catch (e) {
      setState(() => _error = 'Микрофон нээхэд алдаа гарлаа: $e');
    }
  }

  void _onLevel(double level) {
    if (mounted) setState(() => _level = level);
  }

  void _onDetection(Detection d) {
    if (!mounted) return;
    if (d.guess) {
      // Тайлбар төдий тэмдэглэл: зөвхөн түүхэнд нэмнэ
      setState(() {
        _history.insert(0, d);
        if (_history.length > 50) _history.removeLast();
      });
      return;
    }
    if (!_inForeground) _notifier.show(d);
    setState(() {
      _flash = d;
      _history.insert(0, d);
      if (_history.length > 50) _history.removeLast();
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
    // Чичиргээгээр ялгана: нэр = хурдан гурав, бусад чимээ = энгийн хэмнэлээр хоёр
    d.isName ? _buzz(3, fast: true) : _buzz(2);
  }

  Future<void> _buzz(int times, {bool fast = false}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iPhone: системийн хүчтэй чичиргээ (дуудлага ирэхтэй адил). Чичиргээний багцын
      // ашигладаг CoreHaptics нь микрофон бичиж байх үед мэдрэгдэхгүй байсан.
      for (var i = 0; i < times; i++) {
        HapticFeedback.vibrate();
        await Future<void>.delayed(Duration(milliseconds: fast ? 450 : 800));
      }
      return;
    }
    Vibration.vibrate(
      pattern: [
        for (var i = 0; i < times; i++) ...[
          i == 0 ? 0 : (fast ? 120 : 400),
          fast ? 250 : 500,
        ],
      ],
    );
  }

  String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final flash = _flash;
    final faint = faintOf(context);
    final ink = inkOf(context);
    // Том карт: яаралтай бол шар, бусад үед урвуу өнгө (бараанд цагаан, цайварт хар)
    final flashInk = flash != null && flash.urgent
        ? Colors.black
        : Theme.of(context).colorScheme.surface;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: NavBar(
          items: const [
            (Icons.home_outlined, 'Нүүр'),
            (Icons.graphic_eq, 'Чимээ таних'),
            (Icons.record_voice_over_outlined, 'Нэрс'),
            (Icons.forum_outlined, 'Workspace'),
            (Icons.explore_outlined, 'Чимээний зүг'),
            (Icons.person_outline, 'Тохиргоо'),
          ],
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
        body: switch (_tab) {
          1 => SoundsScreen(settings: _settings, engine: _engine),
          2 => NamesScreen(
            settings: _settings,
            hasNameModel: _engine.hasNameModel,
          ),
          3 => WorkspaceScreen(engine: _engine, messages: _workspace),
          4 => FinderScreen(engine: _engine),
          5 => ProfileScreen(settings: _settings, auth: widget.auth),
          // Нүүр: жижиг дэлгэцэд багтахгүй бол гүйлгэж болно
          _ => SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 38,
                                  height: 38,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Sonor',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_engine.isDemo) ...[
                                const SizedBox(width: 10),
                                Glass(
                                  radius: 10,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    'Демо',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: faint,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Сонсох товч нь дээд мөр ба мэдрэмжийн картын яг голд байрлана. Сүүлийн дохионы
                          // том карт товчны дээр, энэ хэсгийн дээд талд гарна.
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 120,
                                  ),
                                  child: Center(
                                    child: LiquidButton(
                                      active: _listening,
                                      level: (_level * 8).clamp(0.0, 1.0),
                                      icon: _listening
                                          ? Icons.graphic_eq
                                          : Icons.mic_none,
                                      label: _listening
                                          ? 'Сонсож байна'
                                          : 'Сонсох',
                                      onTap: _ready ? _toggle : null,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 112,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: flash == null
                                        ? Center(
                                            key: const ValueKey('idle'),
                                            child: Text(
                                              _error ??
                                                  (!_ready
                                                      ? 'Загвар ачаалж байна…'
                                                      : _listening
                                                      ? 'Чимээ гарвал энд харагдана'
                                                      : 'Товчийг дарж сонсож эхэлнэ'),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: _error == null
                                                    ? faint
                                                    : urgentAmber,
                                              ),
                                            ),
                                          )
                                        : SizedBox.expand(
                                            key: ValueKey(flash.time),
                                            child: Glass(
                                              radius: 28,
                                              tint: flash.urgent
                                                  ? urgentAmber
                                                  : ink,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 22,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    flash.icon,
                                                    size: 46,
                                                    color: flashInk,
                                                  ),
                                                  const SizedBox(width: 18),
                                                  Expanded(
                                                    child: Text(
                                                      flash.label,
                                                      style: TextStyle(
                                                        color: flashInk,
                                                        fontSize: 23,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SensitivityCard(settings: _settings),
                          const SizedBox(height: 12),
                          if (_history.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 6,
                                bottom: 6,
                              ),
                              child: Text(
                                'Сүүлд таньсан',
                                style: TextStyle(color: faint, fontSize: 13),
                              ),
                            ),
                            Glass(
                              child: Column(
                                children: [
                                  for (final d in _history.take(3))
                                    ListTile(
                                      dense: true,
                                      leading: Icon(
                                        d.icon,
                                        color: d.urgent
                                            ? urgentAmber
                                            : (d.guess ? faint : null),
                                      ),
                                      title: Text(
                                        d.label,
                                        style: d.guess
                                            ? TextStyle(color: faint)
                                            : null,
                                      ),
                                      trailing: Text(
                                        _clock(d.time),
                                        style: TextStyle(color: faint),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const AdBanner(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}

/// Ивээн тэтгэгчийн мөр. Одоогоор байршлын ЖИШЭЭ: гэрээ байгуулагдтал «Жишээ зар» шошготой.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Glass(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: inkOf(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'P',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sponsored by',
                  style: TextStyle(color: faint, fontSize: 12),
                ),
                const Text(
                  'Pinecone',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: faint),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Жишээ зар',
              style: TextStyle(color: faint, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
