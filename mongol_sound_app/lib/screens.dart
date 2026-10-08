import 'package:flutter/material.dart';

import 'auth.dart';
import 'glass.dart';
import 'settings.dart';
import 'sound_engine_stub.dart' if (dart.library.ffi) 'sound_engine.dart';
import 'sounds.dart';

/// Цэсийн хуудсуудын нийтлэг хүрээ.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Text(
        text,
        style: TextStyle(color: faintOf(context), fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: faintOf(context),
          fontSize: 13,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Мэдрэмжийн гулсуур. Нэр, бэлэн чимээ, заасан чимээ, чанга чимээний дохио бүгдэд үйлчилнэ.
class SensitivityCard extends StatelessWidget {
  const SensitivityCard({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final small = TextStyle(color: faintOf(context), fontSize: 12);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Glass(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Мэдрэмж',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text('${(settings.sensitivity * 100).round()}%', style: small),
              ],
            ),
            SizedBox(
              height: 36,
              child: Slider(
                value: settings.sensitivity,
                onChanged: settings.setSensitivity,
                divisions: 10,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Буруу дохио бага', style: small),
                Text('Сул чимээг ч барина', style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Нэр, хочоо оруулах хуудас.
class NamesScreen extends StatefulWidget {
  const NamesScreen({
    super.key,
    required this.settings,
    required this.hasNameModel,
  });
  final AppSettings settings;
  final bool hasNameModel;

  @override
  State<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends State<NamesScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final ok = widget.settings.addName(_controller.text);
    setState(() => _error = ok ? null : 'Нэрээ бичнэ үү (давхардаж болохгүй)');
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _Page(
        title: 'Нэрс',
        children: [
          Glass(
            child: SwitchListTile(
              value: settings.nameEnabled,
              onChanged: settings.setNameEnabled,
              title: const Text('Нэр дуудахыг таних'),
              subtitle: const Text('Хэн нэгэн таныг дуудахад мэдэгдэнэ'),
            ),
          ),
          const SizedBox(height: 16),
          Glass(
            child: Column(
              children: [
                for (final name in settings.names)
                  ListTile(
                    leading: const Icon(Icons.record_voice_over),
                    title: Text(name),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Устгах',
                      onPressed: () => settings.removeName(name),
                    ),
                  ),
                if (settings.names.isEmpty)
                  const ListTile(title: Text('Нэр оруулаагүй байна')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Glass(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _add(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'Нэр эсвэл хоч нэмэх',
                      border: InputBorder.none,
                      errorText: _error,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  tooltip: 'Нэмэх',
                ),
              ],
            ),
          ),
          _Hint(
            widget.hasNameModel
                ? 'Нэр таних загвар нь тухайн нэр дээр сургагдсан байх ёстой. Шинээр нэмсэн нэр, хочийг '
                      'сургалтад оруулсны дараа танина.'
                : 'Нэр таних загвар хараахан нэмэгдээгүй байна. Одоогоор зөвхөн чимээ танина.',
          ),
        ],
      ),
    );
  }
}

/// Аль чимээг сонсохоо сонгох, чимээ заах хуудас.
class SoundsScreen extends StatelessWidget {
  const SoundsScreen({super.key, required this.settings, required this.engine});
  final AppSettings settings;
  final SoundEngine engine;

  void _teach(
    BuildContext context,
    String id,
    String label, {
    bool custom = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeachScreen(
          settings: settings,
          engine: engine,
          id: id,
          label: label,
          custom: custom,
        ),
      ),
    );
  }

  Future<void> _addCustom(BuildContext context) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (label == null || !context.mounted) return;
    final sound = settings.addCustomSound(label);
    if (sound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ийм нэртэй чимээ аль хэдийн байна.')),
      );
      return;
    }
    _teach(context, sound.id, sound.label, custom: true);
  }

  /// Чимээний мөр: зүүн талд дүрс, баруун талд заах "+" товч ба асаах унтраалга.
  Widget _row(
    BuildContext context, {
    required String id,
    required String label,
    required IconData icon,
    bool urgent = false,
    bool custom = false,
  }) {
    final count = settings.recordingCount(id);
    final notes = [
      if (urgent) 'Яаралтай',
      if (count > 0) '$count бичлэг заасан',
      if (custom && count == 0) 'Бичлэг заагаагүй, танихгүй',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 6),
      leading: Icon(icon, color: urgent ? urgentAmber : null),
      title: Text(label),
      subtitle: notes.isEmpty ? null : Text(notes.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(count > 0 ? Icons.mic : Icons.add),
            tooltip: 'Энэ чимээг бичлэгээр заах',
            onPressed: () => _teach(context, id, label, custom: custom),
          ),
          Switch(
            value: settings.enabledSounds.contains(id),
            onChanged: (v) => settings.setSoundEnabled(id, v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _Page(
        title: 'Чимээ таних',
        children: [
          Glass(
            child: SwitchListTile(
              value: settings.describeOthers,
              onChanged: settings.setDescribeOthers,
              title: const Text('Бусад чимээг тэмдэглэх'),
              subtitle: const Text(
                'Жагсаалтад байхгүй чимээг «Хөгжим шиг чимээ» гэх мэтээр түүхэнд '
                'бичнэ. Чичрэхгүй.',
              ),
            ),
          ),
          const _Hint(
            '«+» товчоор чимээг өөрийн гэрт яг яаж сонсогддогоор нь 3–5 удаа бичүүлж зааж болно. '
            'Заасан чимээг апп илүү сайн танина.',
          ),
          const _SectionTitle('Өөрийн чимээ'),
          Glass(
            child: Column(
              children: [
                for (final c in settings.customSounds)
                  _row(
                    context,
                    id: c.id,
                    label: c.label,
                    icon: customSoundIcon,
                    custom: true,
                  ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Шинэ чимээ нэмэх'),
                  subtitle: const Text('Жишээ нь: домофон, угаалгын машин'),
                  onTap: () => _addCustom(context),
                ),
              ],
            ),
          ),
          for (final category in SoundCategory.values) ...[
            _SectionTitle(category.title),
            Glass(
              child: Column(
                children: [
                  for (final e in soundEvents.where(
                    (e) => e.category == category,
                  ))
                    _row(
                      context,
                      id: e.id,
                      label: e.label,
                      icon: e.icon,
                      urgent: e.urgent,
                    ),
                ],
              ),
            ),
          ],
          const _Hint(
            'Таних ажиллагаа бүхэлдээ утсан дээр хийгдэнэ. Дуу бичлэг хадгалагдахгүй, хаашаа ч '
            'илгээгдэхгүй. Заасан чимээнээс зөвхөн тоон хээ нь утсанд үлдэнэ.',
          ),
        ],
      ),
    );
  }
}

/// Шинэ чимээний нэр асуух цонх.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Шинэ чимээ'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Чимээний нэр'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Болих'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Үргэлжлүүлэх')),
      ],
    );
  }
}

/// Нэг чимээг бичлэгээр заах хуудас.
class TeachScreen extends StatefulWidget {
  const TeachScreen({
    super.key,
    required this.settings,
    required this.engine,
    required this.id,
    required this.label,
    this.custom = false,
  });
  final AppSettings settings;
  final SoundEngine engine;
  final String id;
  final String label;
  final bool custom;

  @override
  State<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends State<TeachScreen> {
  static const int _goal = 5;
  static const int _maxSeconds = 15;
  bool _recording = false;
  String? _message;
  bool _failed = false;

  @override
  void dispose() {
    if (_recording) widget.engine.stopSample();
    super.dispose();
  }

  Future<void> _record() async {
    if (_recording) return;
    setState(() {
      _recording = true;
      _message = null;
    });
    final result = await widget.engine.recordSample(maxSeconds: _maxSeconds);
    if (!mounted) return;
    final sample = result.sample;
    if (sample != null) widget.settings.addRecording(widget.id, sample);
    setState(() {
      _recording = false;
      _failed = sample == null;
      _message = result.error ?? 'Бичлэг нэмэгдлээ.';
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _clear() async {
    if (await _confirm(
      'Бичлэгүүдийг арилгах уу?',
      '«${widget.label}» чимээнд заасан бүх бичлэг арилна.',
      'Арилгах',
    )) {
      widget.settings.clearRecordings(widget.id);
      setState(() => _message = null);
    }
  }

  Future<void> _delete() async {
    if (await _confirm(
      'Чимээг устгах уу?',
      '«${widget.label}» чимээ болон түүнд заасан бичлэгүүд устана.',
      'Устгах',
    )) {
      widget.settings.removeCustomSound(widget.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final count = settings.recordingCount(widget.id);
        final full = count >= AppSettings.maxRecordings;
        final ink = inkOf(context);
        return _Page(
          title: widget.label,
          children: [
            Glass(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count == 0 ? 'Бичлэг заагаагүй' : '$count бичлэг заасан',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < _goal; i++)
                        Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: ink.withValues(
                                alpha: i < count ? 1 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '«Бичих» дараад чимээгээ гаргана, дуусмагц «Зогсоох» дарна '
                    '(дээд тал нь $_maxSeconds секунд). $_goal удаа, өөр өөр зайнаас бичвэл '
                    'илүү сайн танина.',
                    style: TextStyle(color: faintOf(context), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (_recording) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(seconds: _maxSeconds),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Бичиж байна… чимээгээ гаргана уу',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.engine.stopSample,
                      icon: const Icon(Icons.stop),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Зогсоох', style: TextStyle(fontSize: 17)),
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: full ? null : _record,
                      icon: const Icon(Icons.mic),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          full ? 'Дээд хязгаарт хүрсэн' : 'Бичих',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                    ),
                  if (_message != null && !_recording) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _failed ? urgentAmber : null),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (count > 0)
              TextButton(
                onPressed: _recording ? null : _clear,
                child: const Text('Бичлэгүүдийг арилгах'),
              ),
            if (widget.custom)
              TextButton(
                onPressed: _recording ? null : _delete,
                child: const Text('Энэ чимээг устгах'),
              ),
            const _Hint(
              'Дуу бичлэг хадгалагдахгүй. Чимээний тоон хээ л утсанд үлдэж, хаашаа ч илгээгдэхгүй.',
            ),
          ],
        );
      },
    );
  }
}

/// Тохиргооны хуудас: бүртгэл, харагдац.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.settings, required this.auth});
  final AppSettings settings;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Тохиргоо',
      children: [
        const _SectionTitle('Бүртгэл'),
        AccountCard(auth: auth),
        const _SectionTitle('Харагдац'),
        AppearanceCard(settings: settings),
      ],
    );
  }
}

/// Бараан, цайвар горим сонгох хэсэг.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key, required this.settings});
  final AppSettings settings;

  static const _modes = [
    (ThemeMode.system, Icons.brightness_auto, 'Утасны тохиргоог дагах'),
    (ThemeMode.light, Icons.light_mode, 'Цайвар'),
    (ThemeMode.dark, Icons.dark_mode, 'Бараан'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Glass(
        child: Column(
          children: [
            for (final (mode, icon, label) in _modes)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: settings.themeMode == mode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => settings.setThemeMode(mode),
              ),
          ],
        ),
      ),
    );
  }
}

/// Нэвтрэх, бүртгүүлэх хэсэг: и-мэйлээ бичээд, ирсэн кодыг оруулна. Нууц үг байхгүй.
class AccountCard extends StatefulWidget {
  const AccountCard({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo; // код илгээсэн хаяг; null бол и-мэйл асуух алхам
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _do(Future<String?> Function() action, VoidCallback onOk) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) {
        onOk();
      } else {
        _code.clear(); // буруу кодыг арилгаж, шууд дахин бичих боломж олгоно
      }
    });
  }

  void _send() => _do(() => widget.auth.sendCode(_email.text), () {
    _sentTo = AuthService.cleanEmail(_email.text);
    _code.clear();
  });

  void _verify() => _do(() => widget.auth.verify(_sentTo!, _code.text), () {
    _sentTo = null;
    _email.clear();
    _code.clear();
  });

  Widget _button(String label, VoidCallback onPressed) => FilledButton(
    onPressed: _busy ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: _busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label, style: const TextStyle(fontSize: 17)),
    ),
  );

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    errorText: _error,
    errorMaxLines: 3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  List<Widget> _signedIn(String email) => [
    const Icon(Icons.check_circle_outline, size: 44),
    const SizedBox(height: 12),
    const Text('Нэвтэрсэн', textAlign: TextAlign.center),
    const SizedBox(height: 4),
    Text(
      email,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 18),
    OutlinedButton(
      onPressed: _busy
          ? null
          : () => _do(() async {
              await widget.auth.signOut();
              return null;
            }, () {}),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Гарах'),
      ),
    ),
  ];

  List<Widget> _askEmail() => [
    const Text(
      'И-мэйлээр нэвтрэх',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text(
      'И-мэйл хаягаа бичнэ. Тань руу 6 оронтой код илгээнэ. Нууц үг хэрэггүй, '
      'анх удаа бол бүртгэл автоматаар үүснэ.',
      style: TextStyle(color: faintOf(context), height: 1.4),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _send(),
      style: const TextStyle(fontSize: 18),
      decoration: _field('ner@example.com'),
    ),
    const SizedBox(height: 14),
    _button('Код авах', _send),
  ];

  List<Widget> _askCode(String sentTo) => [
    const Text(
      'Кодоо оруулна уу',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text(
      '$sentTo хаяг руу код илгээлээ. И-мэйлээ нээгээд кодыг энд бичнэ. '
      'Ирээгүй бол Spam хавтсаа шалгана уу.',
      style: TextStyle(color: faintOf(context), height: 1.4),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _code,
      autofocus: true,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      textAlign: TextAlign.center,
      maxLength: 6,
      onChanged: (v) {
        if (v.length == 6) _verify();
      },
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 10,
      ),
      decoration: _field('000000').copyWith(counterText: ''),
    ),
    const SizedBox(height: 14),
    _button('Нэвтрэх', _verify),
    const SizedBox(height: 6),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _sentTo = null;
                  _error = null;
                }),
          child: const Text('Хаяг солих'),
        ),
        TextButton(
          onPressed: _busy ? null : _send,
          child: const Text('Дахин илгээх'),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final email = auth.email;
        final sentTo = _sentTo;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Glass(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: !auth.available
                    ? const [
                        Text(
                          'Нэвтрэх үйлчилгээ хараахан холбогдоогүй байна.',
                          textAlign: TextAlign.center,
                        ),
                      ]
                    : email != null
                    ? _signedIn(email)
                    : sentTo != null
                    ? _askCode(sentTo)
                    : _askEmail(),
              ),
            ),
            const _Hint(
              'Нэвтрэх нь заавал биш. Нэвтрээгүй ч чимээ, нэр таних бүх боломж ажиллана.',
            ),
          ],
        );
      },
    );
  }
}
