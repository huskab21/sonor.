import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'few_shot.dart';
import 'phrasebook.dart';
import 'sounds.dart';

/// Хэрэглэгчийн тохиргоо: нэрс, аль чимээг сонсох, мэдрэмж, харагдац, заасан чимээ.
/// Утсанд хадгалагдана.
class AppSettings extends ChangeNotifier {
  static const int maxRecordings = 10;

  List<String> names = ['Батхүслэн', 'Хүслэн', 'Хүска'];
  bool nameEnabled = true;
  Set<String> enabledSounds = {
    for (final e in soundEvents)
      if (e.defaultOn) e.id,
  };
  double sensitivity = 0.5; // 0 = хатуу (буруу дохио бага), 1 = мэдрэг
  ThemeMode themeMode = ThemeMode.system;
  bool loaded = false; // утаснаас уншиж дууссан эсэх
  bool onboarded = false; // угтах дэлгэцийг үзсэн эсэх
  bool describeOthers =
      true; // каталогт байхгүй чимээг "... шиг чимээ" гэж тэмдэглэх

  bool signMode = false; // бичвэрийг дохионы хурууны үсгээр харуулах
  int points = 0; // цуглуулсан оноо (демо, зөвхөн утсанд)
  Set<String> doneTasks = {}; // оноо авсан даалгаврууд

  List<CustomSound> customSounds = [];

  /// «Миний дохио» жагсаалт. Анх удаа демо 10 дохиотой эхэлнэ.
  List<SignPhrase> phrases = [...demoPhrases];

  /// Чимээний id -> заасан бичлэгүүд. Бичлэг бүр нь нэг буюу хэд хэдэн embedding
  /// дараалуулсан жагсаалт. Дуу өөрөө хадгалагдахгүй.
  Map<String, List<Float32List>> samples = {};

  /// Заасан бичлэг өөрчлөгдөх бүрд нэмэгдэнэ (хөдөлгүүр дахин сургах дохио).
  int samplesRevision = 0;

  /// Мэдрэмжээс хамаарч босгыг 1.5x (хатуу) - 0.5x (мэдрэг) болгож үржүүлнэ.
  double get thresholdScale => 1.5 - sensitivity;

  /// Заасан чимээний ангилагчийн босго: 0.75 (хатуу) - 0.45 (мэдрэг).
  double get customThreshold => 0.6 + (0.5 - sensitivity) * 0.3;

  /// Нэрийн загварын босгыг мэдрэмжээр тохируулна: [base] 0.90 бол 0.98 (хатуу) - 0.82 (мэдрэг).
  double nameThreshold(double base) =>
      (base + (0.5 - sensitivity) * 0.16).clamp(0.5, 0.99);

  int recordingCount(String id) => samples[id]?.length ?? 0;

  Future<void> load() async {
    if (loaded) return;
    final prefs = await SharedPreferences.getInstance();
    names = prefs.getStringList('names') ?? names;
    nameEnabled = prefs.getBool('nameEnabled') ?? nameEnabled;
    enabledSounds =
        prefs.getStringList('enabledSounds')?.toSet() ?? enabledSounds;
    sensitivity = prefs.getDouble('sensitivity') ?? sensitivity;
    describeOthers = prefs.getBool('describeOthers') ?? describeOthers;
    onboarded = prefs.getBool('onboarded') ?? onboarded;
    points = prefs.getInt('points') ?? points;
    signMode = prefs.getBool('signMode') ?? signMode;
    doneTasks = prefs.getStringList('doneTasks')?.toSet() ?? doneTasks;
    themeMode =
        ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ?? themeMode;
    final storedPhrases = prefs.getString('phrases');
    if (storedPhrases != null) {
      phrases = [
        for (final j in (jsonDecode(storedPhrases) as List))
          SignPhrase.fromJson(j as Map<String, dynamic>),
      ];
      // Демо жагсаалт 10-аас 50 болсон: хуучин хэрэглэгчид шинэ дохиог нэг удаа нэмнэ
      if ((prefs.getInt('phrasesDemo') ?? 10) < demoPhrases.length) {
        phrases = mergeDemoPhrases(phrases);
      }
    }
    final custom = prefs.getString('customSounds');
    if (custom != null) {
      customSounds = [
        for (final c in jsonDecode(custom) as List)
          CustomSound(c['id'] as String, c['label'] as String),
      ];
    }
    final stored = prefs.getString('samples');
    if (stored != null) {
      samples = {
        for (final MapEntry(:key, :value)
            in (jsonDecode(stored) as Map<String, dynamic>).entries)
          key: [for (final s in value as List) decodeFloats(s as String)],
      };
      samplesRevision++;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('names', names);
    await prefs.setBool('nameEnabled', nameEnabled);
    await prefs.setStringList('enabledSounds', enabledSounds.toList());
    await prefs.setDouble('sensitivity', sensitivity);
    await prefs.setBool('describeOthers', describeOthers);
    await prefs.setBool('onboarded', onboarded);
    await prefs.setInt('points', points);
    await prefs.setBool('signMode', signMode);
    await prefs.setStringList('doneTasks', doneTasks.toList());
    await prefs.setString('themeMode', themeMode.name);
    await prefs.setInt('phrasesDemo', demoPhrases.length);
    await prefs.setString(
      'phrases',
      jsonEncode([for (final p in phrases) p.toJson()]),
    );
    await prefs.setString(
      'customSounds',
      jsonEncode([
        for (final c in customSounds) {'id': c.id, 'label': c.label},
      ]),
    );
  }

  Future<void> _saveSamples() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'samples',
      jsonEncode({
        for (final MapEntry(:key, :value) in samples.entries)
          key: value.map(encodeFloats).toList(),
      }),
    );
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void _samplesChanged() {
    samplesRevision++;
    _saveSamples();
    _changed();
  }

  /// Нэр нэмнэ. Хоосон эсвэл давхардсан бол false.
  bool addName(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        names.any((n) => n.toLowerCase() == clean.toLowerCase())) {
      return false;
    }
    names = [...names, clean];
    _changed();
    return true;
  }

  void removeName(String name) {
    names = names.where((n) => n != name).toList();
    _changed();
  }

  void setNameEnabled(bool value) {
    nameEnabled = value;
    _changed();
  }

  void setSoundEnabled(String id, bool value) {
    enabledSounds = {...enabledSounds};
    value ? enabledSounds.add(id) : enabledSounds.remove(id);
    _changed();
  }

  void setSensitivity(double value) {
    sensitivity = value;
    _changed();
  }

  void setOnboarded() {
    onboarded = true;
    _changed();
  }

  void setDescribeOthers(bool value) {
    describeOthers = value;
    _changed();
  }

  void addPhrase(SignPhrase phrase) {
    if (phrases.any((p) => p.id == phrase.id)) return;
    phrases = [...phrases, phrase];
    _changed();
  }

  void removePhrase(int id) {
    phrases = phrases.where((p) => p.id != id).toList();
    _changed();
  }

  /// Даалгаврын оноог нэг удаа нэмнэ.
  void earn(String task, int amount) {
    if (!doneTasks.add(task)) return;
    points += amount;
    _changed();
  }

  void setSignMode(bool value) {
    signMode = value;
    _changed();
  }

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    _changed();
  }

  /// Өөрийн чимээ нэмнэ. Хоосон эсвэл давхардсан нэртэй бол null.
  CustomSound? addCustomSound(String label) {
    final clean = label.trim();
    final taken = [
      ...soundEvents.map((e) => e.label),
      ...customSounds.map((c) => c.label),
    ].any((l) => l.toLowerCase() == clean.toLowerCase());
    if (clean.isEmpty || taken) return null;
    final sound = CustomSound(
      'custom_${DateTime.now().microsecondsSinceEpoch}',
      clean,
    );
    customSounds = [...customSounds, sound];
    enabledSounds = {...enabledSounds, sound.id};
    _changed();
    return sound;
  }

  void removeCustomSound(String id) {
    customSounds = customSounds.where((c) => c.id != id).toList();
    enabledSounds = {...enabledSounds}..remove(id);
    if (samples.remove(id) != null) {
      _samplesChanged();
    } else {
      _changed();
    }
  }

  /// Нэг бичлэгийн embedding-үүдийг нэмнэ. Дээд хязгаарт хүрсэн бол false.
  bool addRecording(String id, Float32List embeddings) {
    if (recordingCount(id) >= maxRecordings) return false;
    samples = {
      ...samples,
      id: [...?samples[id], embeddings],
    };
    _samplesChanged();
    return true;
  }

  void clearRecordings(String id) {
    if (samples[id] == null) return;
    samples = {...samples}..remove(id);
    _samplesChanged();
  }
}
