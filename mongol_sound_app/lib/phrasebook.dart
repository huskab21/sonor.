import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'glass.dart';
import 'learn.dart';
import 'lessons.dart';
import 'sentence.dart';
import 'settings.dart';
import 'sign.dart';
import 'sign_cache_stub.dart' if (dart.library.ffi) 'sign_cache.dart';
import 'sign_catalog.dart';

/// mnsl.mn («Монгол дохионы хэл» толь бичиг)-ийн нэг дохио. Зүрхэлсэн дохионы видео л
/// утсанд хадгалагдана ([SignCache]); бусдыг сайтаас нь шууд тоглуулна.
class SignPhrase {
  const SignPhrase(this.id, this.title, this.video, this.page);
  final int id; // толь бичгийн дугаар
  final String title;
  final String video; // mp4 хаяг
  final String page; // толь бичгийн хуудас

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'video': video,
    'page': page,
  };

  static SignPhrase fromJson(Map<String, dynamic> j) => SignPhrase(
    j['id'] as int,
    j['title'] as String,
    j['video'] as String,
    j['page'] as String,
  );
}

const String _site = 'https://mnsl.mn';

const String _v = '$_site/wp-content/uploads/2024/08'; // видеонууд
const String _p = '$_site/ug'; // толь бичгийн хуудсууд

/// Демо: өдөр тутмын харилцаанд хамгийн хэрэгтэй 50 дохио (mnsl.mn-ээс, сэдвээр нь
/// эрэмбэлсэн): мэндчилгээ, хариу, хүн, асуулт, хэрэгцээ, өдөр тутам, яаралтай.
const List<SignPhrase> demoPhrases = [
  // Мэндчилгээ
  SignPhrase(
    28,
    'Сайн байна уу?',
    '$_v/0028_САЙН-БАЙНА-УУ.mp4',
    '$_p/28-сайн-байна-уу/',
  ),
  SignPhrase(24, 'Сайн уу?', '$_v/0024_САЙН-УУ.mp4', '$_p/24-сайн-уу/'),
  SignPhrase(
    240,
    'Баяртай',
    '$_v/0240_БАЯРТАЙ.mp4',
    '$_p/240-баяртай-үдэн-гаргах-үед/',
  ),
  SignPhrase(137, 'Баярлалаа', '$_v/0137_БАЯРЛАЛАА.mp4', '$_p/137-баярлалаа/'),
  SignPhrase(
    56,
    'Уучлаарай',
    '$_v/0056_УУЧЛААРАЙ.mp4',
    '$_p/56-уучлаарай-өршөөгөөрэй-хүлцэл-өчих/',
  ),
  // Хариу
  SignPhrase(1337, 'Тийм', '$_v/1337_ТИЙМ.mp4', '$_p/1337-тийм-тэгнэ/'),
  SignPhrase(1090, 'Үгүй', '$_v/1090_ҮГҮЙ.mp4', '$_p/1090-үгүй/'),
  SignPhrase(
    1260,
    'За, ойлголоо',
    '$_v/1260_ЗА_ЗӨВ.mp4',
    '$_p/1260-за-ойлголоо-тэгье-хүлээн-зөвшөөрсө/',
  ),
  SignPhrase(1258, 'Зөв', '$_v/1258_ЗӨВ.mp4', '$_p/1258-зөв-мөн/'),
  SignPhrase(279, 'Зүгээр', '$_v/0279_ЗҮГЭЭР.mp4', '$_p/279-зүгээр/'),
  SignPhrase(1013, 'Мэдэхгүй', '$_v/1013_МЭДЭХГҮЙ.mp4', '$_p/1013-мэдэхгүй/'),
  SignPhrase(
    1062,
    'Ойлгохгүй байна',
    '$_v/1062_ОЙЛГОХГҮЙ.mp4',
    '$_p/1062-ойлгохгүй-ойлгомжгүй/',
  ),
  SignPhrase(
    940,
    'Дахиад хэлээч',
    '$_v/0940_ДАХИН.mp4',
    '$_p/940-дахин-дахиад-давтах/',
  ),
  SignPhrase(
    965,
    'Хүлээгээрэй',
    '$_v/0965_ХҮЛЭЭХ.mp4',
    '$_p/965-хүлээх-азнах/',
  ),
  // Хүн
  SignPhrase(987, 'Би', '$_v/0987_БИ.mp4', '$_p/987-би/'),
  SignPhrase(968, 'Чи, та', '$_v/0968_ЧИ-ТА.mp4', '$_p/968-чи-та-чиний-танай/'),
  SignPhrase(409, 'Бид', '$_v/0409_БИД.mp4', '$_p/409-бид-бид-нар-бид-бүхэн/'),
  SignPhrase(29, 'Ээж', '$_v/0029_ЭЭЖ.mp4', '$_p/29-ээж-эх/'),
  SignPhrase(660, 'Найз', '$_v/0660_НАЙЗ.mp4', '$_p/660-найз-найз-нөхөр-анд/'),
  SignPhrase(
    1245,
    'Сонсголгүй',
    '$_v/1245_СОНСГОЛГҮЙ.mp4',
    '$_p/1245-сонсголгүй-дүлий-сонсголын-бэрхшээ/',
  ),
  SignPhrase(
    136,
    'Хайртай',
    '$_v/0136_ХАЙРТАЙ.mp4',
    '$_p/136-хайртай-хайр-сэтгэлтэй-хайрлах/',
  ),
  // Асуулт
  SignPhrase(1208, 'Юу?', '$_v/1208_ЮУ.mp4', '$_p/1208-юу-юунд-яагаад/'),
  SignPhrase(1046, 'Хэн?', '$_v/1046_ХЭН.mp4', '$_p/1046-хэн/'),
  SignPhrase(96, 'Хаана?', '$_v/0096_ХААНА.mp4', '$_p/96-хаана-хаашаа/'),
  SignPhrase(880, 'Хэзээ?', '$_v/0880_ХЭЗЭЭ.mp4', '$_p/880-хэзээ/'),
  SignPhrase(820, 'Яагаад?', '$_v/0820_ЯАГААД.mp4', '$_p/820-яагаад/'),
  SignPhrase(823, 'Яаж?', '$_v/0823_ЯАЖ.mp4', '$_p/823-яаж-хэрхэн/'),
  SignPhrase(327, 'Хэд?', '$_v/0327_ХЭД.mp4', '$_p/327-хэд-хэчнээн/'),
  SignPhrase(
    826,
    'Ямар?',
    '$_v/0826_ЯМАР.mp4',
    '$_p/826-ямар-юмны-чанар-байдал-зан-чанар-буюу/',
  ),
  SignPhrase(
    102,
    'Юу болов?',
    '$_v/0102_ЯАСАН-БЭ.mp4',
    '$_p/102-яасан-юу-болов-яав-яагаад/',
  ),
  // Хэрэгцээ
  SignPhrase(782, 'Туслаач', '$_v/0782_ТУСЛАХ.mp4', '$_p/782-туслах-тусламж/'),
  SignPhrase(
    743,
    'Хэрэгтэй',
    '$_v/0743_ХЭРЭГТЭЙ.mp4',
    '$_p/743-хэрэгтэй-хэрэгцээ-шаардлагатай/',
  ),
  SignPhrase(
    1213,
    'Болохгүй',
    '$_v/1213_БОЛОХГҮЙ.mp4',
    '$_p/1213-болохгүй-хориглох-анхааруулах-үгс-х/',
  ),
  SignPhrase(284, 'Битгий', '$_v/0284_БИТГИЙ.mp4', '$_p/284-битгий-бүү/'),
  SignPhrase(1254, 'Байхгүй', '$_v/1254_БАЙХГҮЙ.mp4', '$_p/1254-байхгүй/'),
  SignPhrase(
    729,
    'Чадахгүй',
    '$_v/0729_ЧАДАХГҮЙ.mp4',
    '$_p/729-чадахгүй-боломжгүй-хүчрэхгүй-болох/',
  ),
  SignPhrase(1010, 'Завгүй', '$_v/1010_ЗАВГҮЙ.mp4', '$_p/1010-завгүй/'),
  SignPhrase(
    1,
    'Нааш ир',
    '$_v/0001_ДУУДАХ.mp4',
    '$_p/1-дуудах-нааш-ир-хүрээд-ир/',
  ),
  SignPhrase(
    1373,
    'Утас',
    '$_v/1373_УТАС.mp4',
    '$_p/1373-утас-гар-утас-утасны-дугаар-цөөн-тох/',
  ),
  // Өдөр тутам
  SignPhrase(481, 'Уух', '$_v/0481_УУХ.mp4', '$_p/481-уух-ундаалах/'),
  SignPhrase(778, 'Хоол', '$_v/0778_ХООЛ.mp4', '$_p/778-хоол/'),
  SignPhrase(
    337,
    'Өлсөх',
    '$_v/0337_ӨЛСӨХ.mp4',
    '$_p/337-өлсөх-өлбөрөх-өлдөх/',
  ),
  SignPhrase(814, 'Ядрах', '$_v/0814_ЯДРАХ.mp4', '$_p/814-ядрах-алжаах/'),
  SignPhrase(
    588,
    'Ажил',
    '$_v/0588_АЖИЛ.mp4',
    '$_p/588-ажил-хөдөлмөр-албан-тушаал/',
  ),
  SignPhrase(
    1180,
    'Мөнгө',
    '$_v/1180_МӨНГӨ.mp4',
    '$_p/1180-мөнгө-төгрөг-үнэ-өртөг/',
  ),
  SignPhrase(103, 'Явах', '$_v/0103_ЯВАХ.mp4', '$_p/103-явах-буцах-харих/'),
  SignPhrase(
    146,
    'Ирэх',
    '$_v/0146_ИРЭХ.mp4',
    '$_p/146-ирэх-айлчлах-морилох-ирэх-гэсэн-утга/',
  ),
  // Яаралтай
  SignPhrase(1034, 'Эмнэлэг', '$_v/1034_ЭМНЭЛЭГ.mp4', '$_p/1034-эмнэлэг/'),
  SignPhrase(
    1268,
    'Өвдөж байна',
    '$_v/1268_ӨВЧИН-ӨВДӨХ.mp4',
    '$_p/1268-өвчин-өвдөх/',
  ),
  SignPhrase(132, 'Цагдаа', '$_v/0132_ЦАГДАА.mp4', '$_p/132-цагдаа/'),
];

/// Хэрэглэгчийн өөрийн дохионы жагсаалт («Миний дуртай», «Ажил дээр» гэх мэт).
/// Дохиог [AppSettings.phrases]-ийн дугаараар нь хадгална.
class SignList {
  const SignList(this.id, this.name, this.ids, {required this.color});
  final String id;
  final String name;
  final List<int> ids;
  final int color; // зүрхний өнгө (ARGB), [listPalette]-аас

  Color get heart => Color(color);

  SignList withIds(List<int> ids) => SignList(id, name, ids, color: color);

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'ids': ids,
    'color': color,
  };

  static SignList fromJson(Map<String, dynamic> j) => SignList(
    j['id'] as String,
    j['name'] as String,
    [for (final i in j['ids'] as List) i as int],
    // Өнгөгүй хадгалсан хуучин жагсаалт: демогийнх өөрийн өнгөтэй, бусад нь цэнхэр
    color:
        j['color'] as int? ??
        demoSignLists.where((l) => l.id == j['id']).firstOrNull?.color ??
        listPalette[2],
  );
}

/// Жагсаалтын зүрхний өнгөнүүд: шинэ жагсаалт ашиглагдаагүй эхний өнгийг авна.
const List<int> listPalette = [
  0xFFFF4D6D, // улаан (Миний дуртай)
  0xFF34C759, // ногоон (Ажил дээр)
  0xFF0A84FF, // цэнхэр
  0xFFFF9F0A, // улбар шар
  0xFFBF5AF2, // ягаан
  0xFF64D2FF, // цайвар цэнхэр
  0xFFFFD60A, // шар
  0xFFAC8E68, // бор
];

/// Ашиглагдаагүй эхний өнгө; бүгд ашиглагдсан бол ээлжлэн.
int nextListColor(List<SignList> lists) {
  final used = {for (final l in lists) l.color};
  return listPalette.firstWhere(
    (c) => !used.contains(c),
    orElse: () => listPalette[lists.length % listPalette.length],
  );
}

/// Дохио бүр аль жагсаалтуудад байгааг өнгөөр нь: дугаар -> зүрхний өнгөнүүд.
Map<int, List<Color>> heartColors(AppSettings settings) {
  final out = <int, List<Color>>{};
  for (final l in settings.signLists) {
    for (final id in l.ids) {
      (out[id] ??= []).add(l.heart);
    }
  }
  return out;
}

/// Анхны жагсаалтууд (демо): демо 50-аас сонгосон.
const List<SignList> demoSignLists = [
  SignList('fav', 'Миний дуртай', [24, 137, 136, 29, 660], color: 0xFFFF4D6D),
  SignList('work', 'Ажил дээр', color: 0xFF34C759, [
    28, 137, 56, 1337, 1090, 1260, 1062, 940, 965, // мэндчилгээ, хариу
    782, 743, 729, 1010, 588, 1373, 880, 96, 1180, // хүсэлт, цаг, газар
  ]),
];

/// Хэрэглэгчийн жагсаалтад байхгүй демо дохиог нэмнэ. Хэрэглэгчийн дараалал,
/// өөрөө нэмсэн дохио хэвээр.
List<SignPhrase> mergeDemoPhrases(List<SignPhrase> mine) {
  final have = {for (final p in mine) p.id};
  return [
    ...mine,
    for (final p in demoPhrases)
      if (!have.contains(p.id)) p,
  ];
}

/// mnsl.mn-ийн толь бичгээс үг хайна (сайтын нийтийн WordPress API).
/// Дугаар, гарчиг, хуудасны хаягийг буцаана; видеог [fetchVideo]-оор авна.
Future<List<({int id, String title, String page})>> searchSigns(
  String query, {
  http.Client? client,
}) async {
  final uri = Uri.parse('$_site/wp-json/wp/v2/ug').replace(
    queryParameters: {
      'search': query,
      'per_page': '20',
      '_fields': 'title,link',
    },
  );
  final res = await (client ?? http.Client()).get(uri);
  if (res.statusCode != 200) throw Exception('mnsl.mn ${res.statusCode}');
  // Сервер кодчиллоо заагаагүй үед кирилл эвдрэхгүйн тулд UTF-8-аар уншина
  final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
  final out = <({int id, String title, String page})>[];
  for (final item in list.cast<Map<String, dynamic>>()) {
    final raw = ((item['title'] as Map)['rendered'] as String)
        .replaceAll('&#8230;', '…')
        .replaceAll('&#8211;', '–');
    final m = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(raw);
    if (m == null) continue;
    out.add((
      id: int.parse(m.group(1)!),
      title: m.group(2)!,
      page: Uri.decodeFull(item['link'] as String),
    ));
  }
  return out;
}

/// Толь бичгийн хуудаснаас дохионы гол видеоны (эхний mp4) хаягийг олно.
Future<String?> fetchVideo(String page, {http.Client? client}) async {
  final res = await (client ?? http.Client()).get(
    Uri.parse(Uri.encodeFull(page)),
  );
  if (res.statusCode != 200) return null;
  final m = RegExp(r'src="([^"]+\.mp4)"')
      .firstMatch(utf8.decode(res.bodyBytes, allowMalformed: true));
  return m == null ? null : Uri.decodeFull(m.group(1)!);
}

/// Зүрхэлсэн дохионы бичлэгийг утсанд хадгалах ажлыг эхлүүлнэ (дуусахыг хүлээхгүй).
/// Хадгалсан өгүүлбэрийн дохионууд мөн хадгалагдана.
void syncSignCache(AppSettings settings) => unawaited(
  SignCache.sync({
    for (final p in settings.heartedPhrases) p.id: p.video,
    for (final x in settings.sentences)
      for (final p in x.words) p.id: p.video,
  }),
);

/// ♡ дарахад гарах цонх: дохиог аль жагсаалтад нэмэхийг сонгоно.
Future<void> showListPicker(
  BuildContext context,
  AppSettings settings,
  SignPhrase phrase,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SText(
                '«${phrase.title}»-ийг аль жагсаалтад нэмэх вэ?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final l in settings.signLists)
              CheckboxListTile(
                value: l.ids.contains(phrase.id),
                secondary: Icon(Icons.favorite, color: l.heart),
                title: SText(l.name),
                subtitle: SText('${l.ids.length} дохио'),
                onChanged: (on) {
                  settings.setInList(l.id, phrase, on ?? false);
                  syncSignCache(settings);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const SText('Шинэ жагсаалт'),
              onTap: () async {
                final list = await _newList(context, settings);
                if (list == null) return;
                settings.setInList(list.id, phrase, true);
                syncSignCache(settings);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SText(
                'Жагсаалтад нэмсэн дохионы бичлэг утсанд хадгалагдаж, '
                'интернэтгүй үзэгдэнэ.',
                style: TextStyle(color: faintOf(context), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Дохио орсон жагсаалтуудын өнгөөр зүрхнүүд (3 хүртэл давхцуулж). Аль ч жагсаалтад
/// ороогүй бол хоосон зүрх.
class HeartStack extends StatelessWidget {
  const HeartStack({super.key, required this.colors, this.size = 20});
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return Icon(Icons.favorite_border, size: size, color: faintOf(context));
    }
    final shown = colors.take(3).toList();
    final step = size * 0.55;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, c) in shown.reversed.indexed)
            Positioned(
              left: step * (shown.length - 1 - i),
              child: Icon(
                Icons.favorite,
                size: size,
                color: c,
                shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
              ),
            ),
        ],
      ),
    );
  }
}

/// Нэр асууж шинэ жагсаалт үүсгэнэ. Болих эсвэл давхардсан нэртэй бол null.
Future<SignList?> _newList(BuildContext context, AppSettings settings) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _ListNameDialog(),
  );
  if (name == null) return null;
  final list = settings.addSignList(name);
  if (list == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: SText('«${name.trim()}» нэртэй жагсаалт байна')),
    );
  }
  return list;
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog();

  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final text = _name.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const SText('Шинэ жагсаалт'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        decoration: const InputDecoration(
          hintText: 'Жишээ нь: Эмнэлэг, Сургууль, Гэр бүл',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const SText('Болих'),
        ),
        FilledButton(onPressed: _done, child: const SText('Үүсгэх')),
      ],
    );
  }
}

/// «Миний дохио»: хэрэгтэй дохиогоо хадгалж, хүнтэй харилцахдаа гаргаж үзүүлнэ.
/// Дээд талын шошгоор жагсаалт сонгоно; ♡-оор дохиог жагсаалтад нэмнэ.
class PhrasebookScreen extends StatefulWidget {
  const PhrasebookScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {
  String? _listId; // null: бүх дохио

  AppSettings get settings => widget.settings;

  @override
  void initState() {
    super.initState();
    syncSignCache(settings); // өмнө татаж амжаагүйг нөхнө
    CatalogStore.load().then((_) => _expandWork());
  }

  /// Толь бичиг анх татагдахад «Ажил дээр»-т «Хөдөлмөр эрхлэлт» сэдвийг нэмнэ.
  void _expandWork() {
    final catalog = CatalogStore.current.value;
    if (catalog == null || settings.workExpanded) return;
    final topic = catalog.mainTopics
        .where((t) => t.name.contains('Хөдөлмөр'))
        .firstOrNull;
    if (topic == null) return;
    settings.expandWorkList(catalog.signsIn(topic.id));
    syncSignCache(settings);
  }

  /// «Толь бичиг: 1398 дохио, 20 сэдэв» товч.
  Widget _catalogBanner(BuildContext context) => ValueListenableBuilder(
    valueListenable: CatalogStore.current,
    builder: (context, catalog, _) => _banner(
      context,
      icon: Icons.menu_book,
      title: 'Толь бичиг',
      subtitle: catalog == null
          ? 'mnsl.mn-ийн бүх дохио, сэдвээр'
          : '${catalog.signs.length} дохио, ${catalog.mainTopics.length} сэдэв',
      page: TopicsScreen(settings: settings),
    ),
  );

  /// «Сургалт»: үе шаттай хичээл, шалгалт.
  Widget _learnBanner(BuildContext context) {
    final done = settings.lessonStars.values.where((s) => s > 0).length;
    return _banner(
      context,
      icon: Icons.school,
      title: 'Сургалт',
      subtitle: done == 0
          ? 'Дохионы хэлийг алхам алхмаар: үсэг, тоо, үг'
          : '$done / ${allLessons.length} хичээл дууссан',
      page: LearnScreen(settings: settings),
    );
  }

  /// «Өгүүлбэр»: дохионуудыг дараалуулж тасралтгүй тоглуулах.
  Widget _sentenceBanner(BuildContext context) => _banner(
    context,
    icon: Icons.playlist_play,
    title: 'Өгүүлбэр зохиох',
    subtitle: settings.sentences.isEmpty
        ? 'Дохионуудыг дараалуулаад нэг дор тоглуулна'
        : '${settings.sentences.length} өгүүлбэр хадгалсан',
    page: SentencesScreen(settings: settings),
  );

  Widget _banner(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) => GestureDetector(
    onTap: () =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page)),
    child: Glass(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon, color: accentOf(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SText(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SText(
                  subtitle,
                  style: TextStyle(color: faintOf(context), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, SignCache.saved]),
      builder: (context, _) {
        final list = settings.signLists
            .where((l) => l.id == _listId)
            .firstOrNull;
        final phrases = list == null
            ? settings.phrases
            : settings.phrasesIn(list);
        final hearts = heartColors(settings);
        final offline = SignCache.saved.value;
        final mb = (SignCache.bytes.value / 1e6).toStringAsFixed(1);
        return Backdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: backButton(context),
              leadingWidth: backWidth,
              title: const SText('Миний дохио'),
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: 'Дохио нэмэх',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SignSearchScreen(settings: settings, listId: _listId),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _learnBanner(context),
                  const SizedBox(height: 8),
                  _catalogBanner(context),
                  const SizedBox(height: 8),
                  _sentenceBanner(context),
                  const SizedBox(height: 12),
                  _listChips(context),
                  const SizedBox(height: 12),
                  if (phrases.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SText(
                        list == null
                            ? 'Жагсаалт хоосон. Баруун дээд «+» товчоор дохио нэмнэ үү.'
                            : 'Энэ жагсаалт хоосон. «Бүгд»-ээс дохионы ♡ дээр дарж нэмнэ үү.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: faint),
                      ),
                    ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
                    children: [
                      for (final p in phrases)
                        SignCard(
                          phrase: p,
                          settings: settings,
                          hearts: hearts[p.id] ?? const [],
                          offline: offline.contains(p.id),
                          onLongPress: () => _confirmRemove(context, p, list),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                    child: SText(
                      'Дарахад дохионы бичлэг томоор гарна: утсаа харилцаж буй хүндээ '
                      'үзүүлнэ. ♡ дарж жагсаалтад нэмнэ; жагсаалтад байгаа дохио '
                      'утсанд хадгалагдаж интернэтгүй үзэгдэнэ (${offline.length} '
                      'дохио, $mb MB). Удаан дарвал хасна. Бичлэгүүд mnsl.mn '
                      '(«Монгол дохионы хэл» толь бичиг)-ийнх.',
                      style: TextStyle(color: faint, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// «Бүгд · Миний дуртай · Ажил дээр · ＋» шошгууд. Удаан дарвал жагсаалтыг устгана.
  Widget _listChips(BuildContext context) {
    Widget chip({
      required Widget label,
      required bool selected,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      IconData? icon,
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 18, color: color),
          label: label,
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            label: SText('Бүгд ${settings.phrases.length}'),
            selected: _listId == null,
            onTap: () => setState(() => _listId = null),
          ),
          for (final l in settings.signLists)
            chip(
              icon: Icons.favorite,
              color: l.heart,
              label: SText('${l.name} ${l.ids.length}'),
              selected: _listId == l.id,
              onTap: () => setState(() => _listId = l.id),
              onLongPress: () => _confirmRemoveList(context, l),
            ),
          chip(
            icon: Icons.add,
            label: const SText('Шинэ'),
            selected: false,
            onTap: () async {
              final list = await _newList(context, settings);
              if (list != null) setState(() => _listId = list.id);
            },
          ),
        ],
      ),
    );
  }

  /// Жагсаалт дотор бол зөвхөн тэр жагсаалтаас, «Бүгд»-д бол бүрмөсөн хасна.
  Future<void> _confirmRemove(
    BuildContext context,
    SignPhrase p,
    SignList? list,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText(
          list == null
              ? '«${p.title}»-ийг хасах уу?'
              : '«${p.title}»-ийг «${list.name}»-ээс хасах уу?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SText('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const SText('Хасах'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    list == null
        ? settings.removePhrase(p.id)
        : settings.setInList(list.id, p, false);
    syncSignCache(settings);
  }

  Future<void> _confirmRemoveList(BuildContext context, SignList l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText('«${l.name}» жагсаалтыг устгах уу?'),
        content: const SText('Дохионууд «Бүгд»-д хэвээр үлдэнэ.'),
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
    if (_listId == l.id) setState(() => _listId = null);
    settings.removeSignList(l.id);
    syncSignCache(settings);
  }
}

/// Дохионы карт: дарахад бичлэг, ♡-оор жагсаалтад нэмнэ, ✓ бол утсанд хадгалсан.
class SignCard extends StatelessWidget {
  const SignCard({
    super.key,
    required this.phrase,
    required this.settings,
    required this.hearts,
    required this.offline,
    this.onLongPress,
  });
  final SignPhrase phrase;
  final AppSettings settings;
  final List<Color> hearts; // орсон жагсаалтуудын өнгө
  final bool offline;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SignVideoScreen(phrase: phrase, settings: settings),
        ),
      ),
      onLongPress: onLongPress,
      child: Glass(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      size: 28,
                      color: accentOf(context),
                    ),
                    const SizedBox(height: 6),
                    SText(
                      phrase.title,
                      textAlign: TextAlign.center,
                      maxLines: 3, // бүтэн нэр нь бичлэгийн хуудсанд
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (offline)
              Positioned(
                left: 8,
                top: 8,
                child: Tooltip(
                  message: 'Утсанд хадгалсан',
                  child: Icon(
                    Icons.download_done,
                    size: 16,
                    color: faintOf(context),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: 'Жагсаалтад нэмэх',
                visualDensity: VisualDensity.compact,
                icon: HeartStack(colors: hearts),
                onPressed: () => showListPicker(context, settings, phrase),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Дохионуудыг 3 баганаар, ♡ ба ✓ тэмдэгтэй харуулна.
class SignGrid extends StatelessWidget {
  const SignGrid({super.key, required this.signs, required this.settings});
  final List<SignPhrase> signs;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, SignCache.saved]),
      builder: (context, _) {
        final hearts = heartColors(settings);
        final offline = SignCache.saved.value;
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            for (final p in signs)
              SignCard(
                phrase: p,
                settings: settings,
                hearts: hearts[p.id] ?? const [],
                offline: offline.contains(p.id),
              ),
          ],
        );
      },
    );
  }
}

/// «Толь бичиг»: mnsl.mn-ийн бүх дохио сэдвээр, хайлттай.
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _query = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: const SText('Толь бичиг'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              CatalogStore.current,
              CatalogStore.error,
              _query,
            ]),
            builder: (context, _) {
              final catalog = CatalogStore.current.value;
              final error = CatalogStore.error.value;
              if (catalog == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (error == null) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          SText(
                            'Толь бичиг татаж байна…',
                            style: TextStyle(color: faint),
                          ),
                        ] else ...[
                          SText(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: urgentAmber),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: CatalogStore.load,
                            child: const SText('Дахин оролдох'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              final hits = catalog.search(_query.text);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Glass(
                    radius: 28,
                    padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                    child: TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            '${catalog.signs.length} дохионоос хайх (жишээ нь: ус, ээж)',
                        border: InputBorder.none,
                        suffixIcon: _query.text.isEmpty
                            ? const Icon(Icons.search)
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _query.clear,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_query.text.trim().isNotEmpty) ...[
                    if (hits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SText(
                          'Олдсонгүй. Өөр үгээр хайна уу.',
                          style: TextStyle(color: faint),
                        ),
                      ),
                    SignGrid(
                      signs: hits.take(60).toList(),
                      settings: widget.settings,
                    ),
                  ] else
                    for (final t in catalog.mainTopics)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TopicSignsScreen(
                                settings: widget.settings,
                                catalog: catalog,
                                topic: t,
                              ),
                            ),
                          ),
                          child: Glass(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SText(
                                    t.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${catalog.signsIn(t.id).length}',
                                  style: TextStyle(color: faint),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                    child: SText(
                      'Эх сурвалж: mnsl.mn («Монгол дохионы хэл» толь бичиг). '
                      '♡ дарсан дохио утсанд хадгалагдана.',
                      style: TextStyle(color: faint, fontSize: 12),
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

/// Нэг сэдвийн дохионууд; дэд сэдвээр шүүнэ.
class TopicSignsScreen extends StatefulWidget {
  const TopicSignsScreen({
    super.key,
    required this.settings,
    required this.catalog,
    required this.topic,
  });
  final AppSettings settings;
  final SignCatalog catalog;
  final SignTopic topic;

  @override
  State<TopicSignsScreen> createState() => _TopicSignsScreenState();
}

class _TopicSignsScreenState extends State<TopicSignsScreen> {
  late int _topic = widget.topic.id;

  @override
  Widget build(BuildContext context) {
    final subs = widget.catalog.subtopics(widget.topic.id);
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: SText(widget.topic.name),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (subs.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in [widget.topic, ...subs])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: SText(t == widget.topic ? 'Бүгд' : t.name),
                            selected: _topic == t.id,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _topic = t.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SignGrid(
                signs: widget.catalog.signsIn(_topic),
                settings: widget.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Дохионы бичлэгийг нээнэ: утсанд хадгалсан бол түүнийг, үгүй эсвэл нээгдэхгүй бол
/// сайтаас. Дуугүй тул сонсож буй микрофоныг зогсоохгүй. Нээгдэхгүй бол null.
Future<VideoPlayerController?> openSignVideo(SignPhrase phrase) async {
  Future<VideoPlayerController?> init(VideoPlayerController video) async {
    try {
      await video.initialize();
      await video.setVolume(0);
      return video;
    } catch (e) {
      debugPrint('SignVideo ${phrase.id}: $e');
      video.dispose();
      return null;
    }
  }

  final local = await SignCache.localPlayer(phrase.id);
  if (local != null) {
    final video = await init(local);
    if (video != null) return video;
  }
  return init(
    VideoPlayerController.networkUrl(
      Uri.parse(Uri.encodeFull(phrase.video)),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    ),
  );
}

/// Нэг дохиог бүтэн дэлгэцээр, давтан тоглуулна. Хурдыг удаашруулж болно.
class SignVideoScreen extends StatefulWidget {
  const SignVideoScreen({super.key, required this.phrase, this.settings});
  final SignPhrase phrase;
  final AppSettings? settings; // байвал ♡ товч гарна

  @override
  State<SignVideoScreen> createState() => _SignVideoScreenState();
}

class _SignVideoScreenState extends State<SignVideoScreen> {
  VideoPlayerController? _video;
  bool _slow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final video = await openSignVideo(widget.phrase);
    if (!mounted) {
      video?.dispose();
      return;
    }
    if (video == null) {
      setState(
        () => _error = 'Бичлэг нээгдсэнгүй. Интернэт холболтоо шалгана уу.',
      );
      return;
    }
    video
      ..setLooping(true)
      ..play();
    setState(() => _video = video);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final ready = video != null && video.value.isInitialized;
    final settings = widget.settings;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: backButton(context),
        leadingWidth: backWidth,
        title: SText(widget.phrase.title),
        actions: [
          if (settings != null)
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                return IconButton(
                  tooltip: 'Жагсаалтад нэмэх',
                  icon: HeartStack(
                    colors: heartColors(settings)[widget.phrase.id] ?? const [],
                    size: 24,
                  ),
                  onPressed: () =>
                      showListPicker(context, settings, widget.phrase),
                );
              },
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
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: SText(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: urgentAmber),
                        ),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: SText(
                widget.phrase.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
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

/// mnsl.mn-ийн 1398 дохионоос хайж «Миний дохио»-д нэмнэ. [listId] өгвөл тэр
/// жагсаалтад мөн нэмнэ.
class SignSearchScreen extends StatefulWidget {
  const SignSearchScreen({super.key, required this.settings, this.listId});
  final AppSettings settings;
  final String? listId;

  @override
  State<SignSearchScreen> createState() => _SignSearchScreenState();
}

class _SignSearchScreenState extends State<SignSearchScreen> {
  final _query = TextEditingController();
  List<({int id, String title, String page})> _results = [];
  bool _busy = false;
  String? _message;
  int? _adding;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final results = await searchSigns(q);
      setState(() {
        _results = results;
        _message = results.isEmpty ? 'Олдсонгүй. Өөр үгээр хайна уу.' : null;
      });
    } catch (_) {
      setState(
        () => _message = 'Хайлт ажилласангүй. Интернэт холболтоо шалгана уу.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(({int id, String title, String page}) r) async {
    setState(() => _adding = r.id);
    String? video;
    try {
      video = await fetchVideo(r.page);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _adding = null);
    if (video == null) {
      setState(() => _message = 'Энэ дохионы бичлэг олдсонгүй.');
      return;
    }
    final phrase = SignPhrase(r.id, r.title, video, r.page);
    final listId = widget.listId;
    if (listId == null) {
      widget.settings.addPhrase(phrase);
    } else {
      widget.settings.setInList(listId, phrase, true);
      syncSignCache(widget.settings);
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SText('«${r.title}» нэмэгдлээ')));
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    final list = widget.settings.signLists
        .where((l) => l.id == widget.listId)
        .firstOrNull;
    final saved = list == null
        ? {for (final p in widget.settings.phrases) p.id}
        : list.ids.toSet();
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: backButton(context),
          leadingWidth: backWidth,
          title: SText(list == null ? 'Дохио хайх' : '«${list.name}»-д нэмэх'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Glass(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: const InputDecoration(
                            hintText: 'Үг бичих (жишээ нь: ус, ээж, ажил)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _busy ? null : _search,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SText(_message!, style: TextStyle(color: faint)),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 24),
                    children: [
                      for (final r in _results)
                        ListTile(
                          title: SText(r.title),
                          subtitle: Text(
                            '№ ${r.id}',
                            style: TextStyle(color: faint),
                          ),
                          trailing: saved.contains(r.id)
                              ? const Icon(Icons.check_circle)
                              : _adding == r.id
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_circle_outline),
                          onTap: saved.contains(r.id) || _adding != null
                              ? null
                              : () => _add(r),
                        ),
                    ],
                  ),
                ),
                SText(
                  'Толь бичиг: mnsl.mn (1398 дохио)',
                  style: TextStyle(color: faint, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
