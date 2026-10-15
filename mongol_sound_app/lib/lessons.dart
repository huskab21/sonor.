import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'phrasebook.dart';
import 'sign_catalog.dart';

/// «Сургалт»: үе шаттай дохионы хэлний хичээлүүд. Видео нь mnsl.mn-ийнх (толь бичиг,
/// цагаан толгой, тоо), хичээл бүрт Anujin Boldoo-ийн YouTube цувралаас харгалзах
/// хичээл. Уншиж чаддаггүй хүнд зориулж үг бүр зурагтай (emoji).
class LessonDef {
  const LessonDef(
    this.id,
    this.title,
    this.emoji, {
    this.youtube,
    this.words = const [],
    this.letters,
    this.numbers = const [],
    this.intro = false,
  });
  final String id;
  final String title;
  final String emoji;
  final String? youtube; // YouTube бичлэгийн id
  final List<(int, String, String)>
  words; // (толь бичгийн дугаар, зураг, товч нэр)
  final (int, int)? letters; // цагаан толгойн дугаар (1-35), эхлэл ба төгсгөл
  final List<int> numbers;
  final bool intro; // «Дохионы бүтэц»: шалгалтгүй, зөвхөн үзнэ
}

class LessonStage {
  const LessonStage(this.title, this.lessons);
  final String title;
  final List<LessonDef> lessons;
}

/// Хичээлийн нэг үг: бичлэг, зураг, товч нэр.
class LessonItem {
  const LessonItem(this.sign, this.picture, this.label);
  final SignPhrase sign;
  final String picture; // emoji; хоосон бол зөвхөн нэр
  final String label;
}

const String anujinChannel = 'https://www.youtube.com/@AnujinBoldoo01';

const List<LessonStage> course = [
  LessonStage('1. Эхлэл', [
    LessonDef('intro', 'Дохионы бүтэц', '🖐️', intro: true),
    LessonDef(
      'abc1',
      'Хурууны үсэг: А – Й',
      '🔤',
      youtube: 'eu60B3VrGuk',
      letters: (1, 11),
    ),
    LessonDef(
      'abc2',
      'Хурууны үсэг: К – Ф',
      '🔤',
      youtube: 'eu60B3VrGuk',
      letters: (12, 24),
    ),
    LessonDef(
      'abc3',
      'Хурууны үсэг: Х – Я',
      '🔤',
      youtube: 'eu60B3VrGuk',
      letters: (25, 35),
    ),
  ]),
  LessonStage('2. Тоо', [
    LessonDef(
      'num1',
      'Тоо 0 – 10',
      '🔢',
      numbers: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    ),
    LessonDef(
      'num2',
      'Тоо 11 – 20',
      '🔢',
      numbers: [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    ),
    LessonDef(
      'num3',
      'Аравтууд',
      '🔟',
      youtube: 'u1XU6q2gBgU',
      numbers: [20, 30, 40, 50, 60, 70, 80, 90, 100],
    ),
    LessonDef(
      'num4',
      'Зуу, мянга, сая',
      '💯',
      numbers: [100, 200, 500, 1000, 5000, 10000, 100000, 1000000],
    ),
  ]),
  LessonStage('3. Харилцаа', [
    LessonDef(
      'greet',
      'Мэндчилгээ',
      '👋',
      youtube: '-0AVh8MyzTo',
      words: [
        (28, '👋', 'Сайн байна уу?'),
        (24, '🙋', 'Сайн уу?'),
        (137, '🙏', 'Баярлалаа'),
        (240, '🚶', 'Баяртай'),
        (56, '😔', 'Уучлаарай'),
        (209, '🎂', 'Төрсөн өдөр'),
        (214, '🎄', 'Шинэ жил'),
        (663, '🍀', 'Амжилт хүсье'),
      ],
    ),
    LessonDef(
      'answer',
      'Тийм, үгүй',
      '✅',
      words: [
        (1337, '✅', 'Тийм'),
        (1090, '❌', 'Үгүй'),
        (1260, '👌', 'За, ойлголоо'),
        (1258, '✔️', 'Зөв'),
        (945, '✖️', 'Буруу'),
        (279, '🙂', 'Зүгээр'),
        (1013, '🤷', 'Мэдэхгүй'),
        (1062, '😕', 'Ойлгохгүй байна'),
      ],
    ),
    LessonDef(
      'question',
      'Асуух үг',
      '❓',
      youtube: 'OQ--00sa8-s',
      words: [
        (1046, '👤', 'Хэн?'),
        (1208, '❓', 'Юу?'),
        (96, '📍', 'Хаана?'),
        (880, '⏰', 'Хэзээ?'),
        (820, '🤔', 'Яагаад?'),
        (823, '🛠️', 'Яаж?'),
        (327, '🔢', 'Хэд?'),
        (960, '👉', 'Аль нь?'),
      ],
    ),
    LessonDef(
      'pronoun',
      'Төлөөний үг',
      '🫵',
      youtube: '7XVphAaIkdQ',
      words: [
        (987, '🙋', 'Би'),
        (968, '🫵', 'Чи, та'),
        (409, '👥', 'Бид'),
        (961, '👆', 'Тэр'),
        (106, '👨‍👩‍👧', 'Та нар'),
        (990, '🤲', 'Миний'),
        (673, '🪞', 'Өөрөө'),
      ],
    ),
    LessonDef(
      'talk',
      'Харилцан яриа',
      '💬',
      youtube: 'QVcHJJlfoB0',
      words: [
        (940, '🔁', 'Дахиад'),
        (965, '⏳', 'Хүлээх'),
        (782, '🆘', 'Туслаач'),
        (743, '❗', 'Хэрэгтэй'),
        (729, '🚫', 'Чадахгүй'),
        (1010, '📅', 'Завгүй'),
        (1, '🫴', 'Нааш ир'),
        (1373, '📱', 'Утас'),
      ],
    ),
  ]),
  LessonStage('4. Хүн, гэр бүл', [
    LessonDef(
      'family',
      'Гэр бүл',
      '👨‍👩‍👧',
      youtube: 'bjdKSEkjEVo',
      words: [
        (15, '👨', 'Аав'),
        (29, '👩', 'Ээж'),
        (32, '👵', 'Эмээ'),
        (21, '👴', 'Өвөө'),
        (654, '🧑', 'Ах'),
        (655, '👩‍🦰', 'Эгч'),
        (776, '👦', 'Хүү'),
        (777, '👧', 'Охин'),
        (194, '👶', 'Хүүхэд'),
      ],
    ),
    LessonDef(
      'people',
      'Хүн',
      '🧍',
      words: [
        (1151, '🧍', 'Хүн'),
        (660, '🤝', 'Найз'),
        (909, '💁‍♀️', 'Эмэгтэй'),
        (1300, '🙋‍♂️', 'Эрэгтэй'),
        (699, '🧓', 'Хөгшин'),
        (607, '🍼', 'Нярай'),
        (1245, '🧏', 'Сонсголгүй'),
      ],
    ),
    LessonDef(
      'body',
      'Бие эрхтэн',
      '👁️',
      youtube: 'V1HAsrBs-zk',
      words: [
        (893, '🗣️', 'Толгой'),
        (884, '👁️', 'Нүд'),
        (955, '👂', 'Чих'),
        (929, '👃', 'Хамар'),
        (919, '👄', 'Ам'),
        (915, '🦷', 'Шүд'),
        (1018, '✋', 'Гар'),
        (1055, '🦶', 'Хөл'),
        (996, '🫀', 'Зүрх'),
      ],
    ),
    LessonDef(
      'feelings',
      'Сэтгэл хөдлөл',
      '😊',
      youtube: 'HloBp9gebjg',
      words: [
        (136, '🥰', 'Хайртай'),
        (869, '😄', 'Хөгжилтэй'),
        (581, '😢', 'Харамсах'),
        (709, '😠', 'Уурлах'),
        (526, '😨', 'Айх'),
        (651, '😲', 'Гайхах'),
        (926, '🥱', 'Уйдах'),
        (182, '😳', 'Ичих'),
        (994, '😟', 'Санаа зовох'),
      ],
    ),
  ]),
  LessonStage('5. Өдөр тутам', [
    LessonDef(
      'colors',
      'Өнгө',
      '🎨',
      youtube: 'ukcnRDeY1Vg',
      words: [
        (916, '🔴', 'Улаан'),
        (1332, '🟡', 'Шар'),
        (1311, '🟢', 'Ногоон'),
        (773, '🔵', 'Цэнхэр'),
        (843, '⚫', 'Хар'),
        (787, '⚪', 'Цагаан'),
        (829, '🟤', 'Бор'),
        (824, '🟣', 'Нил ягаан'),
        (1374, '🟠', 'Улбар шар'),
        (817, '🌸', 'Ягаан'),
      ],
    ),
    LessonDef(
      'food',
      'Хоол, ундаа',
      '🍲',
      youtube: 'DR0Fp8WoIX8',
      words: [
        (778, '🍲', 'Хоол'),
        (535, '🍞', 'Талх'),
        (1242, '🥚', 'Өндөг'),
        (810, '🍚', 'Цагаан будаа'),
        (481, '🥤', 'Уух'),
        (806, '☕', 'Кофе'),
        (1061, '🍬', 'Чихэр'),
        (542, '🍽️', 'Идэх'),
        (337, '😋', 'Өлсөх'),
      ],
    ),
    LessonDef(
      'fruit',
      'Жимс',
      '🍎',
      youtube: 'pIpQF9wz-dc',
      words: [
        (364, '🍎', 'Алим'),
        (570, '🍌', 'Гадил'),
        (413, '🍇', 'Усан үзэм'),
        (485, '🍉', 'Тарвас'),
        (1198, '🍓', 'Гүзээлзгэнэ'),
        (1170, '🍊', 'Жүрж'),
        (381, '🍐', 'Лийр'),
        (1126, '🍒', 'Интоор'),
        (392, '🍍', 'Хан боргоцой'),
      ],
    ),
    LessonDef(
      'vegetables',
      'Хүнсний ногоо',
      '🥕',
      youtube: 'difZjyZfwCw',
      words: [
        (1122, '🥔', 'Төмс'),
        (1202, '🥕', 'Лууван'),
        (1171, '🧅', 'Сонгино'),
        (268, '🥬', 'Байцаа'),
        (1021, '🍅', 'Улаан лооль'),
        (1315, '🥒', 'Өргөст хэмх'),
        (427, '🌽', 'Эрдэнэшиш'),
        (380, '🍄', 'Мөөг'),
        (482, '🧄', 'Саримс'),
      ],
    ),
    LessonDef(
      'clothes',
      'Хувцас',
      '👕',
      youtube: 'dYrxKX9R7tk',
      words: [
        (297, '👕', 'Хувцас'),
        (712, '👖', 'Өмд'),
        (738, '👟', 'Гутал'),
        (226, '👗', 'Банзал'),
        (177, '🧢', 'Малгай'),
        (762, '👔', 'Зангиа'),
        (149, '😴', 'Унтлагын хувцас'),
      ],
    ),
  ]),
  LessonStage('6. Амьтан, байгаль', [
    LessonDef(
      'animals',
      'Амьтан',
      '🐶',
      youtube: 'lvgZRjHH6I0',
      words: [
        (139, '🐶', 'Нохой'),
        (1320, '🐱', 'Муур'),
        (804, '🐭', 'Хулгана'),
        (489, '🐘', 'Заан'),
        (368, '🦁', 'Арслан'),
        (341, '🐯', 'Бар'),
        (292, '🐻', 'Баавгай'),
        (488, '🐺', 'Чоно'),
        (406, '🦊', 'Үнэг'),
        (567, '🐒', 'Сармагчин'),
      ],
    ),
    LessonDef(
      'livestock',
      'Таван хошуу мал',
      '🐴',
      youtube: 'rw6ym5qPhY0',
      words: [
        (911, '🐴', 'Морь'),
        (1147, '🐄', 'Үхэр'),
        (218, '🐑', 'Хонь'),
        (1113, '🐐', 'Ямаа'),
        (1304, '🐫', 'Тэмээ'),
        (1284, '🐃', 'Сарлаг'),
      ],
    ),
    LessonDef(
      'birds',
      'Шувуу',
      '🐦',
      youtube: 'Adkf3PQVqoo',
      words: [
        (124, '🐦', 'Шувуу'),
        (20, '🐔', 'Тахиа'),
        (453, '🦆', 'Нугас'),
        (1067, '🦉', 'Шар шувуу'),
        (1159, '🦅', 'Бүргэд'),
        (549, '🦜', 'Тоть'),
        (446, '🐧', 'Оцон шувуу'),
        (318, '🦚', 'Тогос'),
      ],
    ),
    LessonDef(
      'nature',
      'Байгаль',
      '⛰️',
      youtube: 'eY0GjqoggoU',
      words: [
        (1271, '☀️', 'Нар'),
        (398, '☁️', 'Үүл'),
        (105, '⛰️', 'Уул'),
        (291, '🌊', 'Далай'),
        (265, '🌳', 'Мод'),
        (300, '🌲', 'Ой'),
        (705, '🪨', 'Чулуу'),
        (1185, '🍃', 'Навч'),
      ],
    ),
    LessonDef(
      'weather',
      'Цаг агаар',
      '🌧️',
      youtube: 'ccEcQ5VOlVM',
      words: [
        (363, '🌧️', 'Бороо'),
        (248, '❄️', 'Цас'),
        (390, '💨', 'Салхи'),
        (775, '⚡', 'Аянга'),
        (261, '🔥', 'Гал'),
        (242, '🌪️', 'Шуурга'),
      ],
    ),
  ]),
  LessonStage('7. Цаг, гэр, ажил', [
    LessonDef(
      'time',
      'Цаг хугацаа',
      '⏰',
      youtube: 'pWqTi96vCio',
      words: [
        (230, '🌅', 'Өглөө'),
        (234, '🌞', 'Өдөр'),
        (5, '🌆', 'Орой'),
        (957, '📅', 'Өнөөдөр'),
        (958, '⏱️', 'Одоо'),
        (1025, '🕐', 'Цаг'),
        (436, '🌷', 'Хавар'),
        (22, '🏖️', 'Зун'),
        (618, '⛄', 'Өвөл'),
      ],
    ),
    LessonDef(
      'home',
      'Гэр орон',
      '🏠',
      youtube: 'WXsM3WIx4-E',
      words: [
        (188, '🛖', 'Гэр'),
        (189, '🏠', 'Байшин'),
        (121, '🚪', 'Хаалга'),
        (1353, '🪟', 'Цонх'),
        (561, '🔑', 'Түлхүүр'),
        (528, '💡', 'Гэрэл'),
        (79, '🪜', 'Шат'),
        (263, '🏢', 'Орон сууц'),
      ],
    ),
    LessonDef(
      'jobs',
      'Мэргэжил',
      '🧑‍🏫',
      youtube: 'CdGEe6eFtho',
      words: [
        (197, '🧑‍🏫', 'Багш'),
        (1058, '🧑‍⚕️', 'Эмч'),
        (132, '👮', 'Цагдаа'),
        (417, '🧑‍🎓', 'Оюутан'),
        (329, '🎤', 'Дуучин'),
        (215, '🧵', 'Оёдолчин'),
        (1230, '👷', 'Инженер'),
        (610, '🪚', 'Мужаан'),
      ],
    ),
    LessonDef(
      'school',
      'Сургууль',
      '🏫',
      youtube: 'VvRlNL2jWWs',
      words: [
        (500, '🏫', 'Сургууль'),
        (793, '🧸', 'Цэцэрлэг'),
        (875, '📚', 'Хичээл'),
        (685, '📓', 'Дэвтэр'),
        (1103, '✂️', 'Хайч'),
        (227, '📏', 'Шугам'),
        (323, '🖍️', 'Өнгийн харандаа'),
        (354, '🧮', 'Тооны машин'),
      ],
    ),
  ]),
];

/// Бүх хичээл дарааллаар (нээгдэх эсэхийг тооцоход).
List<LessonDef> get allLessons => [for (final s in course) ...s.lessons];

/// Хичээл нээгдсэн эсэх: эхнийх эсвэл өмнөх хичээл дор хаяж 1 ⭐-тэй.
bool lessonUnlocked(LessonDef lesson, Map<String, int> stars) {
  final all = allLessons;
  final i = all.indexOf(lesson);
  return i <= 0 || (stars[all[i - 1].id] ?? 0) > 0;
}

/// Шалгалтын алдаанаас ⭐: алдаагүй 3, 2 хүртэл алдаа 2, бусад 1.
int starsFor(int mistakes) => mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);

/// Цагаан толгой, тоо, «Дохионы бүтэц»-ийн бичлэгүүд (mnsl.mn-ийн тусдаа хуудсууд).
class LessonMedia {
  const LessonMedia(this.letters, this.numbers, this.intro);
  final Map<int, SignPhrase> letters; // 1-35 -> үсэг
  final Map<int, SignPhrase> numbers;
  final List<SignPhrase> intro;

  String toJsonString() => jsonEncode({
    'letters': {for (final e in letters.entries) '${e.key}': e.value.toJson()},
    'numbers': {for (final e in numbers.entries) '${e.key}': e.value.toJson()},
    'intro': [for (final p in intro) p.toJson()],
  });

  static LessonMedia fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    Map<int, SignPhrase> map(String key) => {
      for (final e in (j[key] as Map<String, dynamic>).entries)
        int.parse(e.key): SignPhrase.fromJson(e.value as Map<String, dynamic>),
    };
    return LessonMedia(map('letters'), map('numbers'), [
      for (final p in j['intro'] as List)
        SignPhrase.fromJson(p as Map<String, dynamic>),
    ]);
  }
}

const String _site = 'https://mnsl.mn';
final RegExp _mp4 = RegExp(r'src="([^"]+\.mp4)"');

String _decode(String url) {
  try {
    return Uri.decodeFull(url);
  } catch (_) {
    return url;
  }
}

/// Хурууны үсгийн хуудаснаас «N.-А.mp4» хэлбэрийн бичлэгүүдийг дарааллаар нь.
Map<int, SignPhrase> parseLetters(String page) {
  final out = <int, SignPhrase>{};
  for (final m in _mp4.allMatches(page)) {
    final url = _decode(m.group(1)!);
    final name = RegExp(r'/(\d+)\.-([^/]+)\.mp4$').firstMatch(url);
    if (name == null) continue;
    final i = int.parse(name.group(1)!);
    out.putIfAbsent(
      i,
      () =>
          SignPhrase(1000000 + i, name.group(2)!, url, '$_site/хурууны-үсэг/'),
    );
  }
  return out;
}

/// «Тоо» төрлийн бичлэгээс («25. хорин тав (2)») тоо бүрийн эхний хувилбарыг.
Map<int, SignPhrase> parseNumbers(List<Map<String, dynamic>> items) {
  final out = <int, (int, SignPhrase)>{};
  final title = RegExp(r'^([\d,]+)\.\s*(.+?)\s*(?:\((\d+)\))?$');
  for (final item in items) {
    final t = title.firstMatch(
      unescapeHtml((item['title'] as Map)['rendered'] as String).trim(),
    );
    final v = _mp4.firstMatch((item['content'] as Map)['rendered'] as String);
    if (t == null || v == null) continue;
    final n = int.parse(t.group(1)!.replaceAll(',', ''));
    final variant = int.tryParse(t.group(3) ?? '') ?? 1;
    final have = out[n];
    if (have != null && have.$1 <= variant) continue;
    out[n] = (
      variant,
      SignPhrase(
        2000000 + n,
        t.group(2)!,
        _decode(v.group(1)!),
        _decode(item['link'] as String? ?? '$_site/тоо/'),
      ),
    );
  }
  return {for (final e in out.entries) e.key: e.value.$2};
}

/// mnsl.mn-ийн WordPress API-аас (хөтчөөс ч татаж болно: HTML хуудас CORS-гүй).
Future<LessonMedia> fetchLessonMedia({http.Client? client}) async {
  final net = client ?? http.Client();
  try {
    Future<List<Map<String, dynamic>>> api(
      String type,
      Map<String, String> query,
    ) async {
      final items = <Map<String, dynamic>>[];
      for (var p = 1, pages = 1; p <= pages; p++) {
        final res = await net.get(
          Uri.parse('$_site/wp-json/wp/v2/$type').replace(
            queryParameters: {...query, 'per_page': '100', 'page': '$p'},
          ),
        );
        if (res.statusCode != 200) throw Exception('mnsl.mn ${res.statusCode}');
        pages = int.tryParse(res.headers['x-wp-totalpages'] ?? '') ?? 1;
        items.addAll(
          (jsonDecode(utf8.decode(res.bodyBytes)) as List)
              .cast<Map<String, dynamic>>(),
        );
      }
      return items;
    }

    String content(Map<String, dynamic> item) =>
        (item['content'] as Map)['rendered'] as String;

    final letters = parseLetters(
      (await api('khuruu-useg', {'_fields': 'content'})).map(content).join(),
    );
    final introPage = (await api('pages', {
      'slug': 'дохионы-бүтэц',
      '_fields': 'content',
    })).map(content).join();
    final intro = [
      for (final (i, m) in _mp4.allMatches(introPage).indexed)
        SignPhrase(
          3000000 + i,
          'Дохионы 5 бүрдүүлбэр (${i + 1})',
          _decode(m.group(1)!),
          '$_site/дүрэм/дохионы-бүтэц/',
        ),
    ];
    final numbers = parseNumbers(
      await api('too', {'_fields': 'title,content,link'}),
    );
    return LessonMedia(letters, numbers, intro);
  } finally {
    if (client == null) net.close();
  }
}

/// Утсанд хадгалсан хичээлийн бичлэгийн жагсаалт (толь бичгийн адил, кодонд биш).
class LessonMediaStore {
  LessonMediaStore._();

  static final ValueNotifier<LessonMedia?> current = ValueNotifier(null);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static bool _loading = false;

  static Future<void> load({http.Client? client}) async {
    if (_loading || current.value != null) return;
    _loading = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('lessonMedia');
      if (raw != null) {
        try {
          current.value = LessonMedia.fromJsonString(raw);
          return;
        } catch (_) {}
      }
      final media = await fetchLessonMedia(client: client);
      if (media.letters.length < 35 || media.numbers.isEmpty) {
        throw Exception('дутуу');
      }
      current.value = media;
      await prefs.setString('lessonMedia', media.toJsonString());
    } catch (_) {
      error.value = 'Хичээл татагдсангүй. Интернэт холболтоо шалгана уу.';
    } finally {
      _loading = false;
    }
  }
}

/// Хичээлийн үгс. Хэрэгтэй өгөгдөл (толь бичиг, бичлэгийн жагсаалт) ачаалаагүй бол null.
List<LessonItem>? lessonItems(
  LessonDef lesson,
  SignCatalog? catalog,
  LessonMedia? media,
) {
  if (lesson.intro) {
    return media?.intro.map((p) => LessonItem(p, '', p.title)).toList();
  }
  if (lesson.letters case (final from, final to)) {
    if (media == null) return null;
    return [
      for (var i = from; i <= to; i++)
        if (media.letters[i] case final p?) LessonItem(p, '', p.title),
    ];
  }
  if (lesson.numbers.isNotEmpty) {
    if (media == null) return null;
    return [
      for (final n in lesson.numbers)
        if (media.numbers[n] case final p?) LessonItem(p, '', _digits(n)),
    ];
  }
  if (catalog == null) return null;
  final byId = {for (final s in catalog.signs) s.id: s};
  return [
    for (final (id, picture, label) in lesson.words)
      if (byId[id] case final p?) LessonItem(p, picture, label),
  ];
}

/// 1000000 -> «1 000 000»: том тоог уншихад амар.
String _digits(int n) {
  final s = '$n';
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}
