import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'auth.dart';
import 'finder.dart';
import 'glass.dart';
import 'notifier.dart';
import 'phrasebook.dart';
import 'screens.dart';
import 'settings.dart';
import 'false_alarm_stub.dart' if (dart.library.ffi) 'false_alarm.dart';
import 'sound_engine_stub.dart' if (dart.library.ffi) 'sound_engine.dart';
import 'sounds.dart';
import 'standby.dart';
import 'welcome.dart';
import 'workspace.dart';
import 'sign.dart';

/// Танилцуулгын зургийн build (`--dart-define=SONOR_SLIDES=true`): вэб демогийн
/// «Демо» шошгыг нууж, апп утсан дээрхтэй адил харагдана.
const bool slidesBuild = bool.fromEnvironment('SONOR_SLIDES');

void main() {
  // Зургийн build: товчийг бичвэрээр нь олж дарахын тулд accessibility модыг асаана
  if (slidesBuild) WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
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

  /// Гүн бараан дэвсгэр, нил ягаан өргөлттэй загвар (цайвар горимд цагаан дэвсгэр).
  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF14101F);
    final paper = dark ? const Color(0xFF0D0A16) : Colors.white;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    return ThemeData(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accentPurple,
            brightness: brightness,
          ).copyWith(
            primary: dark ? const Color(0xFFA06BFF) : const Color(0xFF7A2BE8),
            onPrimary: Colors.white,
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
      // Гол товчнууд нил ягаан шилжилттэй; идэвхгүй үед энгийн бүдэг дэвсгэр
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(shape),
          // Дэвсгэрийг доорх backgroundBuilder зурна; энд өнгө өгвөл шилжилтийг дарна
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ink.withValues(alpha: 0.4)
                : Colors.white,
          ),
          backgroundBuilder: (context, states, child) => DecoratedBox(
            // Өнгө, шилжилт хоёрыг зэрэг өгвөл шилжилт өнгөний тунгалагаар бүдгэрдэг
            decoration: states.contains(WidgetState.disabled)
                ? BoxDecoration(
                    color: ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  )
                : BoxDecoration(
                    gradient: accentGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
            child: child,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          foregroundColor: ink,
          side: BorderSide(color: accentPurple.withValues(alpha: 0.55)),
        ),
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
        // Дохионы горимыг бүх хуудас, цонхонд дамжуулна
        builder: (context, child) =>
            SignScope(enabled: _settings.signMode, child: child!),
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
  bool _standby =
      false; // хүлээх горим: харанхуй дэлгэц, дохиогоор өнгөөр анивчина
  int _tab = 0; // доод цэсний сонгосон хуудас
  final List<int> _tabHistory = []; // «Буцах» товчинд: өмнө үзсэн хуудсууд
  final List<WorkspaceMessage> _workspace = []; // Workspace хуудасны яриа
  late final SoundEngine _engine = SoundEngine(
    settings: _settings,
    onDetection: _onDetection,
    onLevel: _onLevel,
  );
  final List<Detection> _history = [];
  final Set<Detection> _reported = {}; // «Буруу» гэж тэмдэглэсэн дохионууд
  final List<SoundFix> _fixes = []; // «Чимээний зүг» хуудасны түүх: чимээ + хүч
  final List<double> _recentLevels = []; // сүүлийн 1.5 секундийн түвшин
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
    // Аппаас гарвал хүлээх горим дуусна (дэлгэцийн гэрэлтүүлэг буцаж сэргэнэ)
    if (!_inForeground && _standby) setState(() => _standby = false);
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
        _standby = false;
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
    _recentLevels.add(level);
    if (_recentLevels.length > 6) _recentLevels.removeAt(0);
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
    if (!_inForeground || _standby) _notifier.flash(d);
    final peak = _recentLevels.fold(0.0, (a, b) => a > b ? a : b);
    setState(() {
      _flash = d;
      _history.insert(0, d);
      if (_history.length > 50) _history.removeLast();
      _fixes.insert(0, SoundFix(d, peak));
      if (_fixes.length > 50) _fixes.removeLast();
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

  /// «Буруу дохио»: дууг сургалтад хадгалж, чимээ бол ийм чимээг цаашид дарна
  /// (яаралтай чимээнээс бусад).
  Future<void> _reportFalse(Detection d) async {
    if (!_reported.add(d)) return;
    setState(() {
      if (_flash == d) _flash = null;
    });
    final id = d.id, embedding = d.embedding;
    final suppress = !d.isName && !d.urgent && id != null && embedding != null;
    if (suppress) _settings.addFalseAlarm(id, embedding);
    await saveFalseAlarmClip(d);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SText(
          d.isName
              ? 'Баярлалаа. Энэ дууг нэр таних загварын дараагийн сургалтад '
                    '«нэр биш» жишээ болгоно.'
              : suppress
              ? 'Ойлголоо: ийм чимээнд дахиж дохио өгөхгүй. '
                    'Тохиргоо > Чимээ таних хэсгээс буцаана.'
              : d.urgent
              ? 'Яаралтай чимээ тул дохио хэвээр өгнө. Бичлэгийг хадгаллаа.'
              : 'Тэмдэглэлээ.',
        ),
      ),
    );
  }

  void _openTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tabHistory
        ..remove(i)
        ..add(_tab);
      _tab = i;
    });
  }

  void _back() =>
      setState(() => _tab = _tabHistory.isEmpty ? 0 : _tabHistory.removeLast());

  String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_standby) {
      return StandbyScreen(
        flash: _flash,
        onExit: () => setState(() => _standby = false),
      );
    }
    // Дохио ирэхэд дэлгэц бүтнээрээ чимээний өнгөөр гурван удаа анивчина
    return Stack(
      children: [
        // Доод цэсний хуудсууд «Буцах» товчоор өмнөх хуудас руугаа очно
        TabBack(
          onBack: _tab == 0 ? null : _back,
          child: PopScope(
            canPop: _tab == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: _app(context),
          ),
        ),
        Positioned.fill(child: ColorFlash(flash: _flash)),
      ],
    );
  }

  Widget _app(BuildContext context) {
    final flash = _flash;
    final faint = faintOf(context);
    // Том карт чимээний өнгөөр (дэлгэцийн анивчилттай ижил), бичвэр нь хар
    const flashInk = Colors.black;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: NavBar(
          items: const [
            (Icons.home_outlined, 'Нүүр'),
            (Icons.graphic_eq, 'Чимээ таних'),
            (Icons.record_voice_over_outlined, 'Нэрс'),
            (Icons.forum_outlined, 'Workspace'),
            (Icons.video_library_outlined, 'Миний дохио'),
            (Icons.explore_outlined, 'Чимээний зүг'),
            (Icons.person_outline, 'Тохиргоо'),
          ],
          index: _tab,
          onTap: _openTab,
        ),
        body: switch (_tab) {
          1 => SoundsScreen(settings: _settings, engine: _engine),
          2 => NamesScreen(
            settings: _settings,
            hasNameModel: _engine.hasNameModel,
          ),
          3 => WorkspaceScreen(engine: _engine, messages: _workspace),
          4 => PhrasebookScreen(settings: _settings),
          5 => FinderScreen(engine: _engine, fixes: _fixes),
          6 => ProfileScreen(settings: _settings, auth: widget.auth),
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
                              const SText(
                                'Sonor',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_engine.isDemo && !slidesBuild) ...[
                                const SizedBox(width: 10),
                                Glass(
                                  radius: 10,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: SText(
                                    'Демо',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: faint,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              LanguageToggle(
                                sign: _settings.signMode,
                                onChanged: _settings.setSignMode,
                              ),
                              if (_listening)
                                IconButton(
                                  tooltip: 'Хүлээх горим',
                                  icon: const Icon(Icons.bedtime_outlined),
                                  onPressed: () =>
                                      setState(() => _standby = true),
                                ),
                            ],
                          ),
                          if (_engine.isDemo && !slidesBuild)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                              child: SText(
                                'Вэб демо: дохио, яриа таних нь жишээ. '
                                'Жинхэнээсээ сонсдог апп iPhone дээр ажиллана.',
                                style: TextStyle(fontSize: 12, color: faint),
                              ),
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
                                            child: SText(
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
                                              tint: flashColorOf(flash),
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
                                                    child: SText(
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
                                                  TextButton(
                                                    onPressed: () =>
                                                        _reportFalse(flash),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: flashInk,
                                                      backgroundColor: flashInk
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                    ),
                                                    child: const SText('Буруу'),
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
                              child: SText(
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
                                      title: SText(
                                        d.label,
                                        style: d.guess
                                            ? TextStyle(color: faint)
                                            : null,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SText(
                                            _clock(d.time),
                                            style: TextStyle(color: faint),
                                          ),
                                          if (!d.guess)
                                            IconButton(
                                              tooltip: 'Буруу дохио',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                _reported.contains(d)
                                                    ? Icons.thumb_down
                                                    : Icons.thumb_down_outlined,
                                                size: 18,
                                                color: faint,
                                              ),
                                              onPressed: _reported.contains(d)
                                                  ? null
                                                  : () => _reportFalse(d),
                                            ),
                                        ],
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
            child: const SText(
              'P',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SText(
                  'Sponsored by',
                  style: TextStyle(color: faint, fontSize: 12),
                ),
                const SText(
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
            // Жижиг шошго: дохионы горимд ч энгийн үсгээр (дохиогоор бол зар бүхэлдээ
            // шахагдаж эвдэрнэ)
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
