import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'glass.dart';
import 'lessons.dart';
import 'phrasebook.dart';
import 'settings.dart';
import 'sign.dart';
import 'sign_catalog.dart';

/// YouTube апп (эсвэл хөтөч)-оор нээнэ.
Future<void> openYoutube(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: SText('YouTube нээгдсэнгүй')));
  }
}

/// «Сургалт»: үе шаттай хичээлүүд. Өмнөх хичээлээ ⭐-тэй дуусгавал дараагийнх нээгдэнэ.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  void initState() {
    super.initState();
    CatalogStore.load();
    LessonMediaStore.load();
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    final settings = widget.settings;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: const SText('Сургалт'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              final stars = settings.lessonStars;
              final all = allLessons;
              final done = all.where((l) => (stars[l.id] ?? 0) > 0).length;
              final total = stars.values.fold(0, (a, b) => a + b);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Glass(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('🎓', style: TextStyle(fontSize: 40)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SText(
                                '$done / ${all.length} хичээл',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: done / all.length,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '⭐ $total',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final stage in course) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
                      child: SText(
                        stage.title,
                        style: TextStyle(
                          color: faint,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final lesson in stage.lessons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LessonTile(
                          lesson: lesson,
                          stars: stars[lesson.id] ?? 0,
                          unlocked: lessonUnlocked(lesson, stars),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LessonScreen(
                                settings: settings,
                                lesson: lesson,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Glass(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(
                        Icons.smart_display,
                        color: Color(0xFFFF0033),
                      ),
                      title: const SText('Видео хичээлүүд: Anujin Boldoo'),
                      subtitle: const SText(
                        'YouTube дээрх «Дохионы хэл сураад аваарай» 25 хичээл',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openYoutube(context, anujinChannel),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                    child: SText(
                      'Дохионы бичлэгүүд: mnsl.mn («Монгол дохионы хэл» толь бичиг). '
                      'Хичээл бүрт YouTube товчоор харгалзах видео хичээлийг үзнэ.',
                      style: TextStyle(color: faint, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });
  final LessonDef lesson;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: GestureDetector(
        onTap: unlocked
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: SText('Өмнөх хичээлээ дуусгавал нээгдэнэ 🔒'),
                ),
              ),
        child: Glass(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Text(lesson.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: SText(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (lesson.youtube != null)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.smart_display,
                    size: 18,
                    color: Color(0xFFFF0033),
                  ),
                ),
              unlocked
                  ? Text(
                      '⭐' * stars + '☆' * (3 - stars),
                      style: const TextStyle(fontSize: 16),
                    )
                  : const Icon(Icons.lock_outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Тасралтгүй давтан тоглох дохионы бичлэг (дуугүй).
class LoopingSign extends StatefulWidget {
  const LoopingSign({
    super.key,
    required this.sign,
    this.slow = false,
    this.coverCorner = false,
  });
  final SignPhrase sign;
  final bool slow;

  /// Цагаан толгойн бичлэгт үсэг нь зүүн дээд буланд бичигдсэн байдаг: шалгалтын
  /// үед тагална. (Тооны бичлэгт бичээгүй, гар нь тэнд байдаг тул тагвал болохгүй.)
  final bool coverCorner;

  @override
  State<LoopingSign> createState() => _LoopingSignState();
}

class _LoopingSignState extends State<LoopingSign> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(LoopingSign old) {
    super.didUpdateWidget(old);
    if (old.slow != widget.slow) {
      _video?.setPlaybackSpeed(widget.slow ? 0.5 : 1);
    }
  }

  Future<void> _open() async {
    final video = await openSignVideo(widget.sign);
    if (!mounted) {
      video?.dispose();
      return;
    }
    if (video == null) {
      setState(() => _failed = true);
      return;
    }
    await video.setLooping(true);
    await video.setPlaybackSpeed(widget.slow ? 0.5 : 1);
    await video.play();
    if (mounted) setState(() => _video = video);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: video?.value.aspectRatio ?? 4 / 3,
        child: ColoredBox(
          color: Colors.black,
          child: video != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(video),
                    if (widget.coverCorner)
                      const Align(
                        alignment: Alignment.topLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.3,
                          heightFactor: 0.42,
                          child: ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: Text(
                                '?',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: _failed
                      ? const SText(
                          'Бичлэг нээгдсэнгүй',
                          style: TextStyle(color: urgentAmber),
                        )
                      : const CircularProgressIndicator(),
                ),
        ),
      ),
    );
  }
}

/// Нэг хичээл: эхлээд дохио бүрийг үзэж (зураг, нэртэй), дараа нь шалгалт өгнө.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.settings, required this.lesson});
  final AppSettings settings;
  final LessonDef lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _quiz = false;
  bool _slow = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: SText(lesson.title),
          backgroundColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: () => setState(() => _slow = !_slow),
              child: Text(_slow ? '0.5x' : '1x'),
            ),
            if (lesson.youtube case final id?)
              IconButton(
                tooltip: 'YouTube хичээл',
                icon: const Icon(Icons.smart_display, color: Color(0xFFFF0033)),
                onPressed: () =>
                    openYoutube(context, 'https://www.youtube.com/watch?v=$id'),
              ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              CatalogStore.current,
              CatalogStore.error,
              LessonMediaStore.current,
              LessonMediaStore.error,
            ]),
            builder: (context, _) {
              final items = lessonItems(
                lesson,
                CatalogStore.current.value,
                LessonMediaStore.current.value,
              );
              if (items == null) {
                final error =
                    LessonMediaStore.error.value ?? CatalogStore.error.value;
                return Center(
                  child: error == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SText(
                                error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: urgentAmber),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  CatalogStore.load();
                                  LessonMediaStore.load();
                                },
                                child: const SText('Дахин оролдох'),
                              ),
                            ],
                          ),
                        ),
                );
              }
              if (_quiz) {
                return QuizView(
                  items: items,
                  slow: _slow,
                  coverCorner: lesson.letters != null,
                  onDone: (mistakes) => _finish(starsFor(mistakes)),
                );
              }
              return _learn(context, items);
            },
          ),
        ),
      ),
    );
  }

  Widget _learn(BuildContext context, List<LessonItem> items) {
    final last = _page >= items.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i <= _page ? accentGradient : null,
                      color: i <= _page
                          ? null
                          : inkOf(context).withValues(alpha: 0.15),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) =>
                _LearnCard(item: items[i], slow: _slow, active: i == _page),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              IconButton.filledTonal(
                iconSize: 32,
                onPressed: _page == 0
                    ? null
                    : () => _pages.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: last
                      ? () => widget.lesson.intro
                            ? _finish(3)
                            : setState(() => _quiz = true)
                      : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  icon: Icon(
                    last
                        ? (widget.lesson.intro ? Icons.check : Icons.quiz)
                        : Icons.arrow_forward,
                  ),
                  label: SText(
                    last
                        ? (widget.lesson.intro ? 'Дууслаа' : 'Шалгалт')
                        : 'Дараах',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _finish(int stars) {
    widget.settings.finishLesson(widget.lesson.id, stars);
    final all = allLessons;
    final i = all.indexOf(widget.lesson);
    final next = i + 1 < all.length ? all[i + 1] : null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _ResultScreen(
          settings: widget.settings,
          lesson: widget.lesson,
          stars: stars,
          next: next,
        ),
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    required this.item,
    required this.slow,
    required this.active,
  });
  final LessonItem item;
  final bool slow;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Харагдаж буй хуудасных л тоглоно (бусад нь зогсоно)
        if (active)
          LoopingSign(key: ValueKey(item.sign.id), sign: item.sign, slow: slow)
        else
          const AspectRatio(aspectRatio: 4 / 3, child: SizedBox()),
        const SizedBox(height: 16),
        Glass(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              if (item.picture.isNotEmpty)
                Text(item.picture, style: const TextStyle(fontSize: 72)),
              SText(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: item.picture.isEmpty && item.label.length <= 9
                      ? 64
                      : 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Шалгалт: бичлэг тоглоход 3 сонголтоос (зураг/нэр) зөвийг нь дарна. Буруу хариулсан
/// үгийг төгсгөлд нь нэг удаа дахин асууна.
class QuizView extends StatefulWidget {
  const QuizView({
    super.key,
    required this.items,
    required this.onDone,
    this.slow = false,
    this.coverCorner = false,
  });
  final List<LessonItem> items;
  final ValueChanged<int> onDone; // алдааны тоо
  final bool slow;
  final bool coverCorner;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  final _rng = Random();
  late final List<LessonItem> _queue = [...widget.items]..shuffle(_rng);
  final Set<LessonItem> _retried = {};
  int _asked = 0;
  int _mistakes = 0;
  late List<LessonItem> _options = _optionsFor(_queue.first);
  LessonItem? _picked;

  List<LessonItem> _optionsFor(LessonItem answer) {
    final others = [...widget.items.where((i) => i != answer)]..shuffle(_rng);
    return [answer, ...others.take(2)]..shuffle(_rng);
  }

  void _pick(LessonItem option) {
    if (_picked != null) return;
    final answer = _queue.first;
    final right = option == answer;
    setState(() => _picked = option);
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      _mistakes++;
      if (_retried.add(answer)) _queue.add(answer); // дахин асууна
    }
    Timer(Duration(milliseconds: right ? 700 : 1500), _next);
  }

  void _next() {
    if (!mounted) return;
    _queue.removeAt(0);
    _asked++;
    if (_queue.isEmpty) {
      widget.onDone(_mistakes);
      return;
    }
    setState(() {
      _picked = null;
      _options = _optionsFor(_queue.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final answer = _queue.first;
    final total = widget.items.length + _retried.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _asked / total, minHeight: 8),
          ),
        ),
        LoopingSign(
          key: ValueKey('${answer.sign.id}-$_asked'),
          sign: answer.sign,
          slow: widget.slow,
          coverCorner: widget.coverCorner,
        ),
        const SizedBox(height: 10),
        const Center(child: Text('👇', style: TextStyle(fontSize: 28))),
        const SizedBox(height: 6),
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              item: o,
              state: _picked == null
                  ? null
                  : o == answer
                  ? true
                  : (o == _picked ? false : null),
              onTap: () => _pick(o),
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.item,
    required this.state,
    required this.onTap,
  });
  final LessonItem item;
  final bool? state; // true: зөв (ногоон), false: буруу сонгосон (улаан)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      true => const Color(0xFF34C759),
      false => const Color(0xFFFF3B30),
      null => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color ?? Colors.transparent, width: 3),
          color: color?.withValues(alpha: 0.18),
        ),
        child: Glass(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              if (item.picture.isNotEmpty) ...[
                Text(item.picture, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: SText(
                  item.label,
                  textAlign: item.picture.isEmpty
                      ? TextAlign.center
                      : TextAlign.start,
                  style: TextStyle(
                    fontSize: item.picture.isEmpty && item.label.length <= 9
                        ? 40
                        : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state == true)
                const Icon(Icons.check_circle, color: Color(0xFF34C759)),
              if (state == false)
                const Icon(Icons.cancel, color: Color(0xFFFF3B30)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({
    required this.settings,
    required this.lesson,
    required this.stars,
    required this.next,
  });
  final AppSettings settings;
  final LessonDef lesson;
  final int stars;
  final LessonDef? next;

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lesson.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  '⭐' * stars + '☆' * (3 - stars),
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 12),
                SText(
                  lesson.intro
                      ? 'Дууслаа! Одоо цагаан толгойгоо сурцгаая.'
                      : stars == 3
                      ? 'Гайхалтай! Алдаагүй.'
                      : stars == 2
                      ? 'Сайн байна!'
                      : 'Дуусгалаа. Дахин давтвал илүү сайн болно.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),
                if (next != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            LessonScreen(settings: settings, lesson: next!),
                      ),
                    ),
                    icon: Text(
                      next!.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    label: SText(
                      'Дараах: ${next!.title}',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LessonScreen(settings: settings, lesson: lesson),
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const SText('Дахин'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
