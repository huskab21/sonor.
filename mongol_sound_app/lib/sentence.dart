import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'glass.dart';
import 'phrasebook.dart';
import 'settings.dart';
import 'sign.dart';
import 'sign_catalog.dart';

/// Дохионуудыг дараалуулсан өгүүлбэр. Үг бүрийг бүтнээр нь (бичлэгийн хаягтай)
/// хадгална: толь бичиг эсвэл «Миний дохио»-гоос хамааралгүй.
class SignSentence {
  const SignSentence(this.id, this.words);
  final String id;
  final List<SignPhrase> words;

  String get text => words.map((w) => w.title).join(' ');

  Map<String, Object> toJson() => {
    'id': id,
    'words': [for (final w in words) w.toJson()],
  };

  static SignSentence fromJson(Map<String, dynamic> j) =>
      SignSentence(j['id'] as String, [
        for (final w in j['words'] as List)
          SignPhrase.fromJson(w as Map<String, dynamic>),
      ]);
}

/// Хадгалсан өгүүлбэрүүд: дарахад тоглуулна, ✎-ээр засна, удаан дарвал устгана.
class SentencesScreen extends StatelessWidget {
  const SentencesScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: const SText('Өгүүлбэр'),
          backgroundColor: Colors.transparent,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, null),
          icon: const Icon(Icons.add),
          label: const SText('Шинэ өгүүлбэр'),
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (settings.sentences.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SText(
                      'Хадгалсан өгүүлбэр алга. «Шинэ өгүүлбэр» дарж дохионуудаа '
                      'дараалуулаад «Тоглуулах» дарвал бичлэгүүд нэг нэгээрээ тасралтгүй тоглоно.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: faint, height: 1.4),
                    ),
                  ),
                for (final x in settings.sentences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SentencePlayerScreen(words: x.words),
                        ),
                      ),
                      onLongPress: () => _confirmRemove(context, x),
                      child: Glass(
                        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle_fill,
                              color: accentOf(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SText(
                                    x.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SText(
                                    '${x.words.length} дохио',
                                    style: TextStyle(
                                      color: faint,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Засах',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(context, x),
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
      ),
    );
  }

  void _edit(BuildContext context, SignSentence? sentence) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SentenceEditorScreen(settings: settings, sentence: sentence),
        ),
      );

  Future<void> _confirmRemove(BuildContext context, SignSentence x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText('«${x.text}»-ийг устгах уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SText('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const SText('Устгах'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    settings.removeSentence(x.id);
    syncSignCache(settings);
  }
}

/// Өгүүлбэр зохиох: үг нэмэх, чирж дараалал солих, хасах, ▶ тоглуулах, хадгалах.
class SentenceEditorScreen extends StatefulWidget {
  const SentenceEditorScreen({
    super.key,
    required this.settings,
    this.sentence,
  });
  final AppSettings settings;
  final SignSentence? sentence; // null: шинэ

  @override
  State<SentenceEditorScreen> createState() => _SentenceEditorScreenState();
}

class _SentenceEditorScreenState extends State<SentenceEditorScreen> {
  late final List<SignPhrase> _words = [...?widget.sentence?.words];
  bool _dirty = false;

  void _add(SignPhrase p) => setState(() {
    _words.add(p);
    _dirty = true;
  });

  void _save() {
    widget.settings.saveSentence(
      SignSentence(
        widget.sentence?.id ??
            'sentence_${DateTime.now().microsecondsSinceEpoch}',
        [..._words],
      ),
    );
    syncSignCache(widget.settings);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: SText('Өгүүлбэр хадгалагдлаа')));
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: SText(widget.sentence == null ? 'Шинэ' : 'Засах'),
          backgroundColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: _words.isEmpty || !_dirty ? null : _save,
              child: const SText('Хадгалах'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Glass(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SText(
                      _words.isEmpty
                          ? '«+ Үг нэмэх» дарж дохио сонгоно уу'
                          : _words.map((w) => w.title).join(' '),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _words.isEmpty ? faint : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false, // ≡ товчоор л чирнэ
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _words.length,
                  onReorderItem: (from, to) => setState(() {
                    _words.insert(to, _words.removeAt(from));
                    _dirty = true;
                  }),
                  itemBuilder: (context, i) => Padding(
                    key: ObjectKey(_words[i]),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Glass(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: accentOf(context),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: SText(_words[i].title, maxLines: 2),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Хасах',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _words.removeAt(i);
                                _dirty = true;
                              }),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_words.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SText(
                    '≡ дээр дарж чирээд дарааллыг солино. Дохионы хэлний '
                    'үгийн дараалал монгол хэлнийхээс өөр байж болно.',
                    style: TextStyle(color: faint, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WordPickerScreen(
                              settings: widget.settings,
                              onPick: _add,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const SText('Үг нэмэх'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _words.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SentencePlayerScreen(words: [..._words]),
                                ),
                              ),
                        icon: const Icon(Icons.play_arrow),
                        label: const SText('Тоглуулах'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Өгүүлбэрт үг сонгох: хоосон үед «Миний дохио», бичихэд толь бичгийн 1398 дохионоос
/// хайна. Сонгоход хуудас хаагдахгүй, дараалан олон үг нэмж болно.
class WordPickerScreen extends StatefulWidget {
  const WordPickerScreen({
    super.key,
    required this.settings,
    required this.onPick,
  });
  final AppSettings settings;
  final ValueChanged<SignPhrase> onPick;

  @override
  State<WordPickerScreen> createState() => _WordPickerScreenState();
}

class _WordPickerScreenState extends State<WordPickerScreen> {
  final _query = TextEditingController();
  int _added = 0;

  @override
  void initState() {
    super.initState();
    CatalogStore.load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pick(SignPhrase p) {
    widget.onPick(p);
    setState(() => _added++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: SText('«${p.title}» нэмэгдлээ'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: const SText('Үг нэмэх'),
          backgroundColor: Colors.transparent,
          actions: [
            if (_added > 0)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: SText('Болсон ($_added)'),
              ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([CatalogStore.current, _query]),
            builder: (context, _) {
              final catalog = CatalogStore.current.value;
              final q = _query.text.trim();
              final List<SignPhrase> words;
              if (q.isEmpty) {
                words = widget.settings.phrases;
              } else if (catalog != null) {
                words = catalog.search(q).take(60).toList();
              } else {
                words = [
                  ...widget.settings.phrases.where(
                    (p) => p.title.toLowerCase().contains(q.toLowerCase()),
                  ),
                ];
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Glass(
                    radius: 28,
                    padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: catalog == null
                            ? 'Үг хайх'
                            : '${catalog.signs.length} дохионоос хайх',
                        border: InputBorder.none,
                        suffixIcon: q.isEmpty
                            ? const Icon(Icons.search)
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _query.clear,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                    child: SText(
                      q.isEmpty ? 'Миний дохио' : '${words.length} олдлоо',
                      style: TextStyle(color: faint, fontSize: 13),
                    ),
                  ),
                  for (final p in words)
                    ListTile(
                      title: SText(p.title),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => _pick(p),
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

/// Өгүүлбэрийн бичлэгүүдийг нэг нэгээр нь тасралтгүй тоглуулна. Дараагийн бичлэгийг
/// урьдчилан ачаалж, тоглож буй үгийг доор тодруулна; үг дээр дарвал тэрнээс эхэлнэ.
class SentencePlayerScreen extends StatefulWidget {
  const SentencePlayerScreen({super.key, required this.words});
  final List<SignPhrase> words;

  @override
  State<SentencePlayerScreen> createState() => _SentencePlayerScreenState();
}

class _SentencePlayerScreenState extends State<SentencePlayerScreen> {
  final Map<int, Future<VideoPlayerController?>> _loading = {};
  VideoPlayerController? _video;
  int? _videoIndex; // [_video] аль үгийнх
  int _index = 0;
  bool _slow = false;
  bool _loop = true;
  bool _finished = false;
  bool _advancing = false;
  final Set<int> _failed = {};

  @override
  void initState() {
    super.initState();
    _start(0);
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    for (final f in _loading.values) {
      unawaited(f.then((v) => v?.dispose()));
    }
    super.dispose();
  }

  /// [i] дэх бичлэгийг ачаална (урьдчилан ачаалсан бол түүнийг).
  Future<VideoPlayerController?> _load(int i) =>
      _loading[i] ??= openSignVideo(widget.words[i]);

  Future<void> _start(int i) async {
    _advancing = true;
    setState(() {
      _index = i;
      _finished = false;
    });
    final old = _video;
    VideoPlayerController? video;
    if (old != null && _videoIndex == i) {
      video = old; // нэг үгтэй өгүүлбэрийг давтах: дахин ачаалахгүй
    } else {
      old?.removeListener(_onTick);
      video = await _load(i);
      // Хүлээх зуур өөр үг сонгосон бол тэр нь үргэлжилнэ (энэ нь дараа ашиглагдана)
      if (!mounted || _index != i) return;
      _loading.remove(i);
      if (old != null) {
        _video = null;
        unawaited(old.dispose());
      }
    }
    if (video == null) {
      _failed.add(i);
      _videoIndex = null;
      _advancing = false;
      _next();
      return;
    }
    await video.setLooping(false);
    await video.setPlaybackSpeed(_slow ? 0.5 : 1);
    await video.seekTo(Duration.zero);
    await video.play();
    if (!identical(video, old)) video.addListener(_onTick);
    if (!mounted) return;
    setState(() {
      _video = video;
      _videoIndex = i;
    });
    _advancing = false;
    if (i + 1 < widget.words.length) unawaited(_load(i + 1)); // урьдчилан
  }

  void _onTick() {
    final v = _video?.value;
    if (v == null || _advancing || !v.isInitialized) return;
    final ended =
        !v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 80);
    if (ended) _next();
  }

  void _next() {
    if (_index + 1 < widget.words.length) {
      _start(_index + 1);
    } else if (_loop && _failed.length < widget.words.length) {
      _start(0);
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final ready = video != null && video.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: backButton(context),
        leadingWidth: backWidth,
        title: SText('${_index + 1}/${widget.words.length}'),
        actions: [
          IconButton(
            tooltip: _loop ? 'Давтах: асаалттай' : 'Давтах: унтраалттай',
            icon: Icon(_loop ? Icons.repeat_on : Icons.repeat),
            onPressed: () => setState(() => _loop = !_loop),
          ),
          TextButton(
            onPressed: () {
              setState(() => _slow = !_slow);
              video?.setPlaybackSpeed(_slow ? 0.5 : 1);
            },
            child: Text(
              _slow ? '0.5x' : '1x',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _finished
                    ? FilledButton.icon(
                        onPressed: () => _start(0),
                        icon: const Icon(Icons.replay),
                        label: const SText('Дахин тоглуулах'),
                      )
                    : ready
                    ? AspectRatio(
                        aspectRatio: video.value.aspectRatio,
                        child: VideoPlayer(video),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, w) in widget.words.indexed)
                    GestureDetector(
                      onTap: () => _start(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: i == _index && !_finished
                              ? accentGradient
                              : null,
                          color: i == _index && !_finished
                              ? null
                              : Colors.white12,
                        ),
                        child: SText(
                          w.title,
                          style: TextStyle(
                            color: _failed.contains(i)
                                ? urgentAmber
                                : Colors.white,
                            fontSize: i == _index ? 22 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                'Эх сурвалж: mnsl.mn',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
