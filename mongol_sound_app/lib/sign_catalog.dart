import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'phrasebook.dart';

/// mnsl.mn-ийн толь бичгийн сэдэв. [parent] 0 бол том сэдэв («4. Хөдөлмөр эрхлэлт»).
class SignTopic {
  const SignTopic(this.id, this.number, this.name, this.parent);
  final int id;
  final String number; // «4.1»: эрэмбэлэхэд
  final String name; // дугааргүй нэр
  final int parent;

  Map<String, Object> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'parent': parent,
  };

  static SignTopic fromJson(Map<String, dynamic> j) => SignTopic(
    j['id'] as int,
    j['number'] as String,
    j['name'] as String,
    j['parent'] as int,
  );
}

/// mnsl.mn-ийн бүх дохио (1398) сэдвүүдийнх нь хамт. Апп ажиллах үедээ сайтаас татаж
/// утсанд хадгална; кодонд хадгалахгүй (сайтын зөвшөөрөл аваагүй).
class SignCatalog {
  const SignCatalog(this.topics, this.signs, this.topicsOf, this.fetched);
  final List<SignTopic> topics;
  final List<SignPhrase> signs; // дугаараар эрэмбэлсэн
  final Map<int, List<int>> topicsOf; // дохионы дугаар -> сэдвүүд
  final DateTime fetched;

  /// Том сэдвүүд дугаарынхаа дарааллаар.
  List<SignTopic> get mainTopics =>
      _sorted([...topics.where((t) => t.parent == 0)]);

  List<SignTopic> subtopics(int main) =>
      _sorted([...topics.where((t) => t.parent == main)]);

  /// Сэдэв (том бол дэд сэдвүүдийнх нь хамт)-ийн дохионууд.
  List<SignPhrase> signsIn(int topic) {
    final ids = {
      topic,
      ...topics.where((t) => t.parent == topic).map((t) => t.id),
    };
    return [...signs.where((s) => topicsOf[s.id]?.any(ids.contains) ?? false)];
  }

  /// Гарчгаар хайна: эхлэлээрээ таарсан нь эхэнд.
  List<SignPhrase> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = [...signs.where((s) => s.title.toLowerCase().contains(q))];
    hits.sort(
      (a, b) =>
          (a.title.toLowerCase().startsWith(q) ? 0 : 1) -
          (b.title.toLowerCase().startsWith(q) ? 0 : 1),
    );
    return hits;
  }

  static List<SignTopic> _sorted(List<SignTopic> list) {
    List<int> key(SignTopic t) => [
      for (final p in t.number.split('.')) int.tryParse(p) ?? 0,
    ];
    return list..sort((a, b) {
      final ka = key(a), kb = key(b);
      for (var i = 0; i < ka.length && i < kb.length; i++) {
        if (ka[i] != kb[i]) return ka[i] - kb[i];
      }
      return ka.length - kb.length;
    });
  }

  String toJsonString() => jsonEncode({
    'fetched': fetched.toIso8601String(),
    'topics': [for (final t in topics) t.toJson()],
    'signs': [
      for (final s in signs) {...s.toJson(), 'topics': topicsOf[s.id] ?? []},
    ],
  });

  static SignCatalog fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final signs = <SignPhrase>[];
    final topicsOf = <int, List<int>>{};
    for (final s in (j['signs'] as List).cast<Map<String, dynamic>>()) {
      final p = SignPhrase.fromJson(s);
      signs.add(p);
      topicsOf[p.id] = [for (final t in s['topics'] as List) t as int];
    }
    return SignCatalog(
      [
        for (final t in j['topics'] as List)
          SignTopic.fromJson(t as Map<String, dynamic>),
      ],
      signs,
      topicsOf,
      DateTime.parse(j['fetched'] as String),
    );
  }
}

const String _api = 'https://mnsl.mn/wp-json/wp/v2';

/// HTML-ийн `&#8220;`, `&amp;` зэргийг энгийн тэмдэгт болгоно.
String unescapeHtml(String s) => s
    .replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    )
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

/// URL-ийн %-кодыг тайлна. Сайтын зарим хаяг эвдэрхий кодтой тул тэр үед хэвээр нь.
String _decode(String url) {
  try {
    return Uri.decodeFull(url);
  } catch (_) {
    return url;
  }
}

/// Сайтаас бүх сэдэв, дохиог татна (нэг хүсэлтэд 100 дохио, нийт ~14 хүсэлт).
Future<SignCatalog> fetchCatalog({http.Client? client}) async {
  final net = client ?? http.Client();
  try {
    Future<http.Response> get(String path, Map<String, String> query) async {
      final res = await net.get(
        Uri.parse('$_api/$path').replace(queryParameters: query),
      );
      if (res.statusCode != 200) throw Exception('mnsl.mn ${res.statusCode}');
      return res;
    }

    List<Map<String, dynamic>> body(http.Response r) =>
        (jsonDecode(utf8.decode(r.bodyBytes)) as List)
            .cast<Map<String, dynamic>>();

    final numbered = RegExp(r'^([\d.]+?)\.?\s+(.*)$');
    final topics = <SignTopic>[
      for (final t in body(
        await get('sedev', {'per_page': '100', '_fields': 'id,name,parent'}),
      ))
        if (numbered.firstMatch(unescapeHtml(t['name'] as String))
            case final m?)
          SignTopic(
            t['id'] as int,
            m.group(1)!,
            m.group(2)!,
            t['parent'] as int,
          ),
    ];

    final signs = <SignPhrase>[];
    final topicsOf = <int, List<int>>{};
    final title = RegExp(r'^(\d+)\.\s*(.*)$');
    final video = RegExp(r'src="([^"]+\.mp4)');
    for (var page = 1, pages = 1; page <= pages; page++) {
      final res = await get('ug', {
        'per_page': '100',
        'page': '$page',
        '_fields': 'title,link,content,sedev',
      });
      pages = int.tryParse(res.headers['x-wp-totalpages'] ?? '') ?? 1;
      for (final item in body(res)) {
        final t = title.firstMatch(
          unescapeHtml((item['title'] as Map)['rendered'] as String),
        );
        final v = video.firstMatch(
          (item['content'] as Map)['rendered'] as String,
        );
        if (t == null || v == null) continue;
        final id = int.parse(t.group(1)!);
        final name = t.group(2)!.trim();
        signs.add(
          SignPhrase(
            id,
            name.isEmpty ? name : name[0].toUpperCase() + name.substring(1),
            _decode(v.group(1)!),
            _decode(item['link'] as String),
          ),
        );
        topicsOf[id] = [for (final s in item['sedev'] as List? ?? []) s as int];
      }
    }
    signs.sort((a, b) => a.id - b.id);
    return SignCatalog(topics, signs, topicsOf, DateTime.now());
  } finally {
    if (client == null) net.close();
  }
}

/// Утсанд хадгалсан толь бичиг. 7 хоногоос хуучин бол дахин татна.
class CatalogStore {
  CatalogStore._();

  static final ValueNotifier<SignCatalog?> current = ValueNotifier(null);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final ValueNotifier<bool> loading = ValueNotifier(false);

  static Future<void> load({bool refresh = false, http.Client? client}) async {
    if (loading.value) return;
    loading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (current.value == null) {
        final raw = prefs.getString('signCatalog');
        if (raw != null) {
          try {
            current.value = SignCatalog.fromJsonString(raw);
          } catch (_) {} // эвдэрсэн бол дахин татна
        }
      }
      final have = current.value;
      final stale =
          have == null ||
          DateTime.now().difference(have.fetched) > const Duration(days: 7);
      if (!refresh && !stale) return;
      final fresh = await fetchCatalog(client: client);
      if (fresh.signs.isEmpty) throw Exception('хоосон');
      current.value = fresh;
      await prefs.setString('signCatalog', fresh.toJsonString());
    } catch (_) {
      // Хуучин хувилбар байвал түүгээрээ үргэлжилнэ
      if (current.value == null) {
        error.value = 'Толь бичиг татагдсангүй. Интернэт холболтоо шалгана уу.';
      }
    } finally {
      loading.value = false;
    }
  }
}
