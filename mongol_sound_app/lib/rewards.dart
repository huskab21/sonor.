import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';
import 'settings.dart';
import 'sign.dart';

const String proName = 'Sonor Pro';
const String proPrice = '9,900₮';

/// Оноо авах даалгаврууд. Одоогоор бүгд демо: оноо зөвхөн утсанд тоологдоно.
const List<({String id, IconData icon, String title, String hint, int points})>
rewardTasks = [
  (
    id: 'survey',
    icon: Icons.assignment_outlined,
    title: 'Судалгаа бөглөх',
    hint: '3 асуулт, 1 минут',
    points: 50,
  ),
  (
    id: 'video',
    icon: Icons.play_circle_outline,
    title: 'Бичлэг үзэх',
    hint: 'Богино бичлэгийг дуустал үзнэ',
    points: 20,
  ),
  (
    id: 'share',
    icon: Icons.thumb_up_alt_outlined,
    title: 'Лайк, шэйр хийх',
    hint: 'Sonor-ийн хуудсыг дэмжинэ',
    points: 10,
  ),
  (
    id: 'invite',
    icon: Icons.group_add_outlined,
    title: 'Найзаа урих',
    hint: 'Урилгын кодоо найздаа илгээнэ',
    points: 100,
  ),
];

Widget _page(String title, List<Widget> children) => Backdrop(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: SText(title), backgroundColor: Colors.transparent),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
    ),
  ),
);

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// Тохиргоо хуудасны хоёр мөр: оноо цуглуулах ба төлбөртэй горим.
class RewardsCard extends StatelessWidget {
  const RewardsCard({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Glass(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.stars_outlined),
              title: const SText('Оноо цуглуулах, мөнгө олох'),
              subtitle: SText(
                '${settings.points} оноо',
                style: TextStyle(color: faint),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, RewardsScreen(settings: settings)),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const SText(proName),
              subtitle: SText(
                'Сарын $proPrice',
                style: TextStyle(color: faint),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const ProScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Оноо цуглуулах хуудас: нийт оноо ба дөрвөн даалгавар.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, required this.settings});
  final AppSettings settings;

  Future<void> _start(BuildContext context, String id, int points) async {
    final done = await switch (id) {
      'survey' => Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const SurveyScreen())),
      'video' => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _VideoDialog(),
      ),
      'share' => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const SText('Лайк, шэйр'),
          content: const SText(
            'Демо: жинхэнэ хувилбарт Sonor-ийн хуудас нээгдэж, лайк дарж, '
            'хуваалцсаны дараа оноо орно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const SText('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const SText('Хийлээ'),
            ),
          ],
        ),
      ),
      _ => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const SText('Найзаа урих'),
          content: const SText(
            'Таны урилгын код:\n\nSONOR-DEMO\n\n'
            'Демо: жинхэнэ хувилбарт найз тань энэ кодоор бүртгүүлэхэд оноо орно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const SText('Болих'),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'SONOR-DEMO'));
                Navigator.pop(context, true);
              },
              child: const SText('Код хуулах'),
            ),
          ],
        ),
      ),
    };
    if (done != true || !context.mounted) return;
    settings.earn(id, points);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SText('+$points оноо нэмэгдлээ')));
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _page('Оноо цуглуулах', [
        Glass(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              SText('Таны оноо', style: TextStyle(color: faint)),
              const SizedBox(height: 4),
              SText(
                '${settings.points}',
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              SText(
                'Оноог мөнгө болгох боломж удахгүй нэмэгдэнэ',
                textAlign: TextAlign.center,
                style: TextStyle(color: faint, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Glass(
          child: Column(
            children: [
              for (final t in rewardTasks)
                ListTile(
                  leading: Icon(t.icon),
                  title: SText(t.title),
                  subtitle: SText(t.hint, style: TextStyle(color: faint)),
                  trailing: settings.doneTasks.contains(t.id)
                      ? const Icon(Icons.check_circle)
                      : SText(
                          '+${t.points}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  onTap: settings.doneTasks.contains(t.id)
                      ? null
                      : () => _start(context, t.id, t.points),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: SText(
            'Демо хувилбар: даалгаврууд жишээ бөгөөд оноо зөвхөн энэ утсанд тоологдоно. '
            'Жинхэнэ мөнгө хараахан олгохгүй.',
            style: TextStyle(color: faint, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

/// Демо судалгаа: гурван асуулт. Бүгдэд хариулбал true буцаана.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  static const questions = [
    (
      'Sonor-ийг хаана хамгийн их хэрэглэдэг вэ?',
      ['Гэртээ', 'Ажил, сургууль дээр', 'Гадаа, замд'],
    ),
    (
      'Танд аль дохио хамгийн чухал вэ?',
      ['Нэр дуудах', 'Хаалга, хонх', 'Гал, сирен', 'Хүүхэд уйлах'],
    ),
    ('Sonor-ийг найздаа санал болгох уу?', ['Тийм', 'Магадгүй', 'Үгүй']),
  ];

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final Map<int, int> _answers = {};

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    const questions = SurveyScreen.questions;
    return _page('Демо судалгаа', [
      for (final (i, (question, options)) in questions.indexed) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
          child: SText(
            '${i + 1}. $question',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        Glass(
          child: Column(
            children: [
              for (final (j, option) in options.indexed)
                ListTile(
                  title: SText(option),
                  trailing: _answers[i] == j ? const Icon(Icons.check) : null,
                  onTap: () => setState(() => _answers[i] = j),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _answers.length == questions.length
            ? () => Navigator.pop(context, true)
            : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: SText('Илгээх', style: TextStyle(fontSize: 17)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
        child: SText(
          'Жишээ судалгаа. Хариулт хаашаа ч илгээгдэхгүй.',
          style: TextStyle(color: faint, fontSize: 13),
        ),
      ),
    ]);
  }
}

/// Демо бичлэг: 5 секунд тоолоод оноо авах товч идэвхжинэ.
class _VideoDialog extends StatefulWidget {
  const _VideoDialog();

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  int _left = 5;
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (t) {
    setState(() => _left--);
    if (_left == 0) t.cancel();
  });

  @override
  void initState() {
    super.initState();
    _timer; // тоолуурыг эхлүүлнэ
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SText('Жишээ бичлэг'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_display_outlined, size: 72),
          const SizedBox(height: 12),
          SText(
            _left > 0 ? 'Бичлэг дуусахад $_left секунд' : 'Бичлэг дууслаа',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const SText('Болих'),
        ),
        FilledButton(
          onPressed: _left > 0 ? null : () => Navigator.pop(context, true),
          child: const SText('Оноо авах'),
        ),
      ],
    );
  }
}

/// Төлбөртэй горимын танилцуулга. Төлбөр хараахан холбогдоогүй.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  static const _perks = [
    (Icons.block, 'Зар сурталчилгаагүй'),
    (Icons.record_voice_over_outlined, 'Өөрийн нэрийг таниулж сургах'),
    (Icons.forum_outlined, 'Workspace-ийн яриа таних хязгааргүй'),
    (Icons.history, 'Таньсан чимээний бүтэн түүх'),
  ];

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return _page(proName, [
      Glass(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 48),
            const SizedBox(height: 10),
            const SText(
              proName,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const SText(
                  proPrice,
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                ),
                SText(' / сар', style: TextStyle(color: faint, fontSize: 17)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Glass(
        child: Column(
          children: [
            for (final (icon, label) in _perks)
              ListTile(leading: Icon(icon), title: SText(label)),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const FilledButton(
        onPressed: null,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: SText('Удахгүй', style: TextStyle(fontSize: 17)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
        child: SText(
          'Төлбөртэй горим хөгжүүлэлтийн шатанд байна. Дээрх боломжууд төлөвлөгөө бөгөөд '
          'өөрчлөгдөж болно. Одоогоор төлбөр авахгүй.',
          style: TextStyle(color: faint, fontSize: 13, height: 1.4),
        ),
      ),
    ]);
  }
}
