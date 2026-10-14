import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'glass.dart';
import 'settings.dart';
import 'sign.dart';

/// mnsl.mn («Монгол дохионы хэл» толь бичиг)-ийн нэг дохио. Видеог апп-д хадгалахгүй,
/// харуулах үедээ сайтаас нь шууд тоглуулна.
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

/// «Миний дохио»: хэрэгтэй дохиогоо хадгалж, хүнтэй харилцахдаа гаргаж үзүүлнэ.
class PhrasebookScreen extends StatelessWidget {
  const PhrasebookScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final phrases = settings.phrases;
        return Backdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const SText('Миний дохио'),
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: 'Дохио нэмэх',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SignSearchScreen(settings: settings),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (phrases.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SText(
                        'Жагсаалт хоосон. Баруун дээд «+» товчоор дохио нэмнэ үү.',
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
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SignVideoScreen(phrase: p),
                            ),
                          ),
                          onLongPress: () => _confirmRemove(context, p),
                          child: Glass(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_fill,
                                  size: 28,
                                  color: accentOf(context),
                                ),
                                const SizedBox(height: 8),
                                SText(
                                  p.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                    child: SText(
                      'Дарахад дохионы бичлэг томоор гарна: утсаа харилцаж буй хүндээ '
                      'үзүүлнэ. Удаан дарвал жагсаалтаас хасна. Бичлэгүүд mnsl.mn '
                      '(«Монгол дохионы хэл» толь бичиг)-ийнх, интернэт хэрэгтэй.',
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

  Future<void> _confirmRemove(BuildContext context, SignPhrase p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText('«${p.title}»-ийг хасах уу?'),
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
    if (ok == true) settings.removePhrase(p.id);
  }
}

/// Нэг дохиог бүтэн дэлгэцээр, давтан тоглуулна. Хурдыг удаашруулж болно.
class SignVideoScreen extends StatefulWidget {
  const SignVideoScreen({super.key, required this.phrase});
  final SignPhrase phrase;

  @override
  State<SignVideoScreen> createState() => _SignVideoScreenState();
}

class _SignVideoScreenState extends State<SignVideoScreen> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(
    Uri.parse(Uri.encodeFull(widget.phrase.video)),
    // Дуугүй бичлэг: сонсож буй микрофоныг зогсоохгүй
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _slow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video
        .initialize()
        .then((_) {
          _video
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) {
            setState(
              () =>
                  _error = 'Бичлэг нээгдсэнгүй. Интернэт холболтоо шалгана уу.',
            );
          }
        });
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _video.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: SText(widget.phrase.title),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _slow = !_slow);
              _video.setPlaybackSpeed(_slow ? 0.5 : 1);
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
                        aspectRatio: _video.value.aspectRatio,
                        child: VideoPlayer(_video),
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

/// mnsl.mn-ийн 1398 дохионоос хайж «Миний дохио»-д нэмнэ.
class SignSearchScreen extends StatefulWidget {
  const SignSearchScreen({super.key, required this.settings});
  final AppSettings settings;

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
    widget.settings.addPhrase(SignPhrase(r.id, r.title, video, r.page));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SText('«${r.title}» нэмэгдлээ')));
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    final saved = {for (final p in widget.settings.phrases) p.id};
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const SText('Дохио хайх'),
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
