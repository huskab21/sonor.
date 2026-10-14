import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mongol_sound_app/auth.dart';
import 'package:mongol_sound_app/few_shot.dart';
import 'package:mongol_sound_app/finder.dart';
import 'package:mongol_sound_app/phrasebook.dart';
import 'package:mongol_sound_app/settings.dart';
import 'package:mongol_sound_app/sign.dart';
import 'package:mongol_sound_app/speaker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mongol_sound_app/sounds.dart';
import 'package:mongol_sound_app/transcriber.dart';
import 'package:mongol_sound_app/welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final classNames = parseClassMap(
    File('assets/yamnet_class_map.csv').readAsStringSync(),
  );

  test('YAMNet-ийн 521 ангиллыг зөв уншина', () {
    expect(classNames.length, 521);
    expect(classNames[0], 'Speech');
    // Таслалтай нэр хашилтгүйгээр, бүтнээрээ уншигдана
    expect(classNames[1], 'Child speech, kid speaking');
  });

  test('Чимээний үйл явдал бүрийн ангилал YAMNet-д байгаа', () {
    for (final event in soundEvents) {
      for (final name in event.classes) {
        expect(classNames, contains(name), reason: '${event.label}: $name');
      }
    }
  });

  test(
    'Тайлбарлах чимээ бүрийн ангилал YAMNet-д байгаа, каталогтой давхцахгүй',
    () {
      final catalog = soundEvents.expand((e) => e.classes).toSet();
      for (final name in describedClasses.keys) {
        expect(classNames, contains(name));
        expect(catalog, isNot(contains(name)));
      }
    },
  );

  test('Чимээний хүч децибелээр 0-1 хооронд хувирна', () {
    final strength = FinderScreen.strength;
    expect(strength(0), 0);
    expect(strength(0.001), closeTo(0, 1e-9)); // -60 дБ
    expect(strength(0.01), closeTo(0.4, 1e-9)); // -40 дБ
    expect(strength(1), 1);
    expect(strength(0.1), greaterThan(strength(0.05)));
  });

  test('Зайн таамаг: 6 дБ сулрахад хоёр дахина холдоно, нам гүмд хоосон', () {
    final meters = FinderScreen.meters;
    final near = meters(0.04)!; // ойролцоогоор -28 дБ = 1 м
    expect(near, closeTo(1, 0.05));
    expect(meters(0.02)!, closeTo(near * 2, 0.01));
    expect(meters(0.04, loudSource: true)!, greaterThan(near));
    expect(meters(0.001), isNull);
    expect(FinderScreen.metersText(null), 'чимээгүй');
    expect(FinderScreen.metersText(0.4), '1 м дотор');
    expect(FinderScreen.metersText(2.0), '≈ 2 м');
    expect(FinderScreen.metersText(2.6), '≈ 2.5 м');
    expect(FinderScreen.metersText(8.2), '≈ 8 м');
    expect(FinderScreen.metersText(40), '15 м-ээс хол');
  });

  test('Оноо: даалгавар бүрийн оноо нэг л удаа нэмэгдэнэ', () {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    settings.earn('survey', 50);
    settings.earn('survey', 50);
    settings.earn('video', 20);
    expect(settings.points, 70);
    expect(settings.doneTasks, {'survey', 'video'});
  });

  test('Тасралтгүй чимээ: сүүлийн 6 шалгалтын 5-д сул босго давбал дохио', () {
    final tracker = SustainTracker();
    for (var i = 0; i < 4; i++) {
      expect(tracker.add('water', true), isFalse);
    }
    expect(tracker.add('water', false), isFalse); // нэг удаа тасалдав
    expect(tracker.add('water', true), isTrue); // 6-аас 5
    tracker.reset('water');
    expect(tracker.add('water', true), isFalse); // дахин 3 секунд хэрэгтэй
    // Тасархай чимээ хэзээ ч хүрэхгүй
    for (var i = 0; i < 20; i++) {
      expect(tracker.add('knock', i.isEven), isFalse);
    }
    expect(
      soundEvents.where((e) => e.sustained).map((e) => e.id),
      containsAll(['water', 'fire', 'siren', 'baby']),
    );
  });

  test(
    'Түвшин тэгшитгэх: нам дууг өсгөнө, чимээгүй ба чанга дууг хөндөхгүй',
    () {
      Float32List tone(double amp) => Float32List.fromList([
        for (var i = 0; i < 1600; i++) amp * math.sin(i * 0.3),
      ]);
      final quiet = tone(0.014); // rms ~0.01
      final gain = normalizeLevel(quiet);
      expect(gain, closeTo(5, 0.2));
      expect(rms(quiet), closeTo(0.05, 0.002));
      final faint = tone(0.007); // rms ~0.005: дээд тал нь 8 дахин
      expect(normalizeLevel(faint), 8);
      expect(normalizeLevel(tone(0.001)), 1); // шуугиан
      expect(normalizeLevel(tone(0.3)), 1); // аль хэдийн чанга
    },
  );

  test('Дохионы цагаан толгой: 35 үсэг бүр зурагтай', () {
    expect(signAlphabet.runes.length, 35);
    for (final rune in signAlphabet.runes) {
      final asset = signAsset(String.fromCharCode(rune));
      expect(asset, isNotNull);
      expect(File(asset!).existsSync(), isTrue, reason: asset);
    }
    expect(signAsset('Ү'), signAsset('ү'));
    expect(signAsset('5'), isNull);
    expect(signAsset('a'), isNull); // латин үсэг
  });

  testWidgets('SText: энгийн үед бичвэр, дохионы горимд үсэг бүр зураг', (
    tester,
  ) async {
    Widget app(bool sign) => MaterialApp(
      home: SignScope(
        enabled: sign,
        child: const Scaffold(body: SText('Ус 5')),
      ),
    );
    await tester.pumpWidget(app(false));
    expect(find.text('Ус 5'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(app(true));
    expect(find.byType(Image), findsNWidgets(2));
  });

  test('mnsl.mn: хайлтын хариу, видеоны хаягийг уншина', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/wp-json/wp/v2/ug')) {
        expect(req.url.queryParameters['search'], 'ус');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'title': {'rendered': '1054. үнэртэй ус'},
                'link': 'https://mnsl.mn/ug/1054-%d2%af%d0%bd%d1%8d%d1%80%d1%82%d1%8d%d0%b9-%d1%83%d1%81/',
              },
              {
                'title': {'rendered': 'гарчиггүй'},
                'link': 'https://mnsl.mn/x/',
              },
            ]),
          ),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          '<video><source src="https://mnsl.mn/a/1054_%D0%A3%D0%A1.mp4" type="video/mp4"></video>',
        ),
        200,
      );
    });
    final results = await searchSigns('ус', client: client);
    expect(results.length, 1);
    expect(results.first.id, 1054);
    expect(results.first.title, 'үнэртэй ус');
    expect(results.first.page, 'https://mnsl.mn/ug/1054-үнэртэй-ус/');
    expect(
      await fetchVideo(results.first.page, client: client),
      'https://mnsl.mn/a/1054_УС.mp4',
    );
  });

  test('Миний дохио: демо 50-аар эхэлж, давхардуулахгүй нэмж, хасна', () {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    expect(settings.phrases.length, 50);
    expect({for (final p in demoPhrases) p.id}.length, 50); // давхардалгүй
    settings.addPhrase(demoPhrases.first);
    expect(settings.phrases.length, 50);
    settings.addPhrase(const SignPhrase(1054, 'үнэртэй ус', 'v', 'p'));
    expect(settings.phrases.last.id, 1054);
    settings.removePhrase(28);
    expect(settings.phrases.any((p) => p.id == 28), isFalse);
  });

  test('Хуучин 10 дохиотой жагсаалтад шинэ демо нэмэгдэж, өөрийнх хэвээр', () {
    const mine = [
      SignPhrase(1054, 'үнэртэй ус', 'v', 'p'),
      SignPhrase(137, 'Баярлалаа', 'v', 'p'),
    ];
    final merged = mergeDemoPhrases(mine);
    expect(merged.first.id, 1054); // хэрэглэгчийн дараалал эхэндээ
    expect(merged.length, 51);
    expect(merged.where((p) => p.id == 137).length, 1);
  });

  test('Чангаар хэлэх: урт бичвэрийг хувааж, WAV-уудыг нэгтгэнэ', () {
    expect(splitForSpeech('  Сайн   байна уу? '), ['Сайн байна уу?']);
    final long = List.filled(30, 'Өнөөдөр цаг агаар сайхан байна.').join(' ');
    final parts = splitForSpeech(long, max: 100);
    expect(parts.every((p) => p.length <= 100), isTrue);
    expect(parts.join(' '), long);
    expect(parts.first.endsWith('.'), isTrue); // өгүүлбэрийн заагаар таслана

    final a = encodeWav(Float32List.fromList(List.filled(100, 0.1)));
    final b = encodeWav(Float32List.fromList(List.filled(60, -0.1)));
    final joined = joinWav([a, b]);
    final view = ByteData.sublistView(joined);
    expect(joined.length, 44 + 320);
    expect(view.getUint32(40, Endian.little), 320); // data хэмжээ
    expect(view.getUint32(4, Endian.little), joined.length - 8);
    expect(
      view.getInt16(44 + 100 * 2, Endian.little),
      lessThan(0),
    ); // 2 дахь хэсэг араас
  });

  test(
    'Чангаар хэлэх: Chimege TTS-ийн хүсэлт, давтан хэлэхэд сервер дуудахгүй',
    () async {
      var calls = 0;
      final wav = encodeWav(Float32List(10));
      final client = MockClient((req) async {
        calls++;
        expect(req.url.toString(), 'https://api.chimege.com/v1.2/synthesize');
        expect(req.headers['Token'], 'tok');
        expect(req.headers['voice-id'], isNotEmpty);
        expect(utf8.decode(req.bodyBytes), 'Баярлалаа');
        return http.Response.bytes(wav, 200);
      });
      final speaker = Speaker(client: client, token: 'tok');
      expect(speaker.available, isTrue);
      expect(await speaker.synthesize('Баярлалаа '), wav);
      expect(await speaker.synthesize('Баярлалаа'), wav);
      expect(calls, 1);

      final bad = Speaker(
        client: MockClient((_) async => http.Response('', 403)),
        token: 'x',
      );
      expect(
        () => bad.synthesize('а'),
        throwsA(
          isA<SpeakerException>().having(
            (e) => e.message,
            'message',
            contains('эрх'),
          ),
        ),
      );
      expect(Speaker(token: '').available, isFalse);
    },
  );

  test('Ярианы ангиллууд YAMNet-д байгаа; мэдрэмж нэрийн босгыг өөрчилнө', () {
    for (final name in speechClasses) {
      expect(classNames, contains(name));
    }
    final settings = AppSettings();
    expect(settings.nameThreshold(0.9), closeTo(0.9, 1e-9));
    settings.sensitivity = 0;
    expect(settings.nameThreshold(0.9), closeTo(0.98, 1e-9));
    settings.sensitivity = 1;
    expect(settings.nameThreshold(0.9), closeTo(0.82, 1e-9));
  });

  test('Чимээ бүр давтагдашгүй id-тай', () {
    final ids = soundEvents.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('Нэр, хоч нэмж устгана; хоосон болон давхардсаныг авахгүй', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    expect(settings.names, ['Батхүслэн', 'Хүслэн', 'Хүска']);
    expect(settings.addName(' Хүсээ '), isTrue);
    expect(settings.addName('хүсээ'), isFalse);
    expect(settings.addName('  '), isFalse);
    expect(settings.names, ['Батхүслэн', 'Хүслэн', 'Хүска', 'Хүсээ']);
    settings.removeName('Батхүслэн');
    expect(settings.names, ['Хүслэн', 'Хүска', 'Хүсээ']);
  });

  /// [center] чиглэлийн ойролцоох санамсаргүй нэгж вектор.
  Float32List near(Float32List center, math.Random random, double noise) {
    final v = Float32List.fromList([
      for (final c in center) c + noise * random.nextDouble(),
    ]);
    normalize(v);
    return v;
  }

  test('Бичлэгээс чимээтэй цонхыг олно', () {
    final clip = Float32List(sampleRate * 3);
    for (var i = 30000; i < 34000; i++) {
      clip[i] = 0.5 * math.sin(i / 5);
    }
    final starts = pickWindows(clip);
    expect(starts, isNotEmpty);
    for (final s in starts) {
      // Цонх бүр чимээг бүтнээр нь агуулна
      expect(s, lessThanOrEqualTo(30000));
      expect(s + yamnetSamples, greaterThanOrEqualTo(34000));
    }
  });

  test('Урт бичлэгээс давтагдсан чимээ бүрээс давхцахгүй цонх авна', () {
    final clip = Float32List(sampleRate * 15);
    for (final start in [20000, 100000, 200000]) {
      for (var i = start; i < start + 6000; i++) {
        clip[i] = 0.5 * math.sin(i / 5);
      }
    }
    final starts = pickWindows(clip);
    for (final burst in [20000, 100000, 200000]) {
      expect(
        starts.any((s) => s <= burst && s + yamnetSamples >= burst + 6000),
        isTrue,
        reason: 'burst at $burst',
      );
    }
    // Чимээгүй хэсгээс цонх авахгүй
    for (final s in starts) {
      expect(
        [
          20000,
          100000,
          200000,
        ].any((b) => s < b + 6000 && s + yamnetSamples > b),
        isTrue,
      );
    }
    expect(starts.length, lessThanOrEqualTo(9));
  });

  test('Цөөн жишээгээр сургасан ангилагч заасан чимээг бусдаас ялгана', () {
    final random = math.Random(1);
    Float32List axis(int hot) => Float32List(embeddingSize)
      ..fillRange(hot, hot + 100, 1)
      ..fillRange(900, 1000, 0.5);
    final bell = axis(0), knock = axis(200), speech = axis(400);
    Float32List many(Float32List c, int n) => Float32List.fromList([
      for (var i = 0; i < n; i++) ...near(c, random, 0.3),
    ]);

    final weights = trainAll((
      {
        'bell': [many(bell, 3), many(bell, 2)],
        'knock': [many(knock, 4)],
        'empty': <Float32List>[],
      },
      many(speech, 200),
    ));
    expect(weights.keys, unorderedEquals(['bell', 'knock']));
    final clf = SoundClassifier(weights['bell']!);
    // Аппын босго 0.45 (мэдрэг) - 0.75 (хатуу) хооронд хэлбэлзэнэ
    final hit = clf.score(near(bell, random, 0.3));
    final speechScore = clf.score(near(speech, random, 0.3));
    final knockScore = clf.score(near(knock, random, 0.3));
    expect(hit, greaterThan(0.75), reason: 'bell');
    expect(speechScore, lessThan(0.45), reason: 'speech');
    expect(knockScore, lessThan(0.45), reason: 'knock');
  });

  test(
    'Өөрийн чимээ, заасан бичлэг, харагдац хадгалагдаж дахин уншигдана',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      final sound = settings.addCustomSound(' Домофон ')!;
      expect(settings.addCustomSound('домофон'), isNull);
      expect(settings.addCustomSound('Сирен'), isNull);
      expect(settings.enabledSounds, contains(sound.id));

      final sample = Float32List.fromList([
        for (var i = 0; i < embeddingSize; i++) i / embeddingSize,
      ]);
      final before = settings.samplesRevision;
      expect(settings.addRecording(sound.id, sample), isTrue);
      expect(settings.addRecording('knock', sample), isTrue);
      expect(settings.samplesRevision, greaterThan(before));
      settings.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppSettings();
      await reloaded.load();
      expect(reloaded.customSounds.single.label, 'Домофон');
      expect(reloaded.recordingCount(sound.id), 1);
      expect(reloaded.samples['knock']!.single, sample);
      expect(reloaded.themeMode, ThemeMode.light);

      reloaded.removeCustomSound(sound.id);
      expect(reloaded.customSounds, isEmpty);
      expect(reloaded.recordingCount(sound.id), 0);
      expect(reloaded.enabledSounds, isNot(contains(sound.id)));
      reloaded.clearRecordings('knock');
      expect(reloaded.samples, isEmpty);
    },
  );

  test('Заах бичлэгийн тоо дээд хязгаараас хэтрэхгүй', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    final sample = Float32List(embeddingSize);
    for (var i = 0; i < AppSettings.maxRecordings; i++) {
      expect(settings.addRecording('knock', sample), isTrue);
    }
    expect(settings.addRecording('knock', sample), isFalse);
  });

  test(
    'И-мэйл кодоор нэвтэрч гарна; буруу хаяг, буруу кодыг авахгүй',
    () async {
      final auth = AuthService(DemoAuthBackend());
      var changes = 0;
      auth.addListener(() => changes++);
      expect(auth.available, isTrue);
      expect(await auth.sendCode('буруу хаяг'), isNotNull);
      expect(await auth.sendCode('a@b'), isNotNull);
      expect(await auth.sendCode(' Huska@Example.com '), isNull);
      expect(await auth.verify('huska@example.com', '123'), isNotNull);
      expect(await auth.verify('huska@example.com', '000000'), isNotNull);
      expect(auth.email, isNull);
      expect(await auth.verify(' Huska@Example.com ', '123 456'), isNull);
      expect(auth.email, 'huska@example.com');
      await auth.signOut();
      expect(auth.email, isNull);
      expect(changes, greaterThan(0));
    },
  );

  test('Нэвтрэх үйлчилгээ холбогдоогүй бол алдаа буцаана, унахгүй', () async {
    final auth = AuthService();
    expect(auth.available, isFalse);
    expect(auth.email, isNull);
    expect(await auth.sendCode('huska@example.com'), isNotNull);
    await auth.signOut();
  });

  testWidgets('Угтах дэлгэц: гулсуулахад нэвтрэх алхам, алгасахад дуусна', (
    tester,
  ) async {
    var done = 0;
    final auth = AuthService(DemoAuthBackend());
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeFlow(auth: auth, onDone: () => done++),
      ),
    );
    expect(find.text('Чимээг мэдэр'), findsOneWidget);

    // Дутуу гулсуулбал буцна
    final knob = find.byIcon(Icons.keyboard_double_arrow_right);
    await tester.drag(knob, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('И-мэйлээр нэвтрэх'), findsNothing);

    await tester.drag(knob, const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('И-мэйлээр нэвтрэх'), findsOneWidget);
    expect(done, 0);

    await tester.tap(find.text('Нэвтрэхгүйгээр үнэгүй ашиглах'));
    expect(done, 1);
  });

  testWidgets('Нэвтрэх үйлчилгээгүй бол угтах дэлгэцээс шууд апп руу орно', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeFlow(auth: AuthService(), onDone: () => done++),
      ),
    );
    await tester.drag(
      find.byIcon(Icons.keyboard_double_arrow_right),
      const Offset(600, 0),
    );
    expect(done, 1);
  });

  test('WAV толгой зөв: 16 кГц, нэг суваг, 16 бит', () {
    final wav = encodeWav(Float32List.fromList([0, 1, -1, 0.5]));
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), 8);
    expect(wav.length, 44 + 8);
    expect(data.getInt16(46, Endian.little), 32767);
    expect(data.getInt16(48, Endian.little), -32767);
  });

  test('Яриа таних: хүсэлтийн хэлбэр, хариу, алдааны бичвэрүүд', () async {
    final speech = Float32List.fromList([
      for (var i = 0; i < sampleRate; i++) 0.3 * math.sin(i / 8),
    ]);
    http.Request? sent;
    Transcriber withStatus(int code, String body) => Transcriber(
      token: 'test-token',
      client: MockClient((request) async {
        sent = request;
        return http.Response.bytes(utf8.encode(body), code);
      }),
    );

    final ok = await withStatus(200, ' Сайн байна уу. ').transcribe(speech);
    expect(ok.text, 'Сайн байна уу.');
    expect(ok.error, isNull);
    expect(sent!.url.toString(), 'https://api.chimege.com/v1.2/transcribe');
    expect(sent!.headers['Token'], 'test-token');
    expect(sent!.headers['Punctuate'], 'true');
    expect(sent!.bodyBytes.length, 44 + sampleRate * 2);

    expect((await withStatus(200, '').transcribe(speech)).error, isNotNull);
    expect(
      (await withStatus(403, 'Invalid API token.').transcribe(speech)).error,
      contains('токен'),
    );
    expect((await withStatus(503, '').transcribe(speech)).error, isNotNull);

    // Чимээгүй бичлэгийг сервер рүү илгээхгүй
    sent = null;
    final quiet = await withStatus(
      200,
      'x',
    ).transcribe(Float32List(sampleRate));
    expect(quiet.text, isNull);
    expect(sent, isNull);

    // Токенгүй бол илгээхгүй, ойлгомжтой алдаа буцаана
    final none = await Transcriber(token: '').transcribe(speech);
    expect(none.error, contains('холбогдоогүй'));
  });

  test(
    'Урт яриаг 14 секундээс хэтрэхгүй хэсгүүдэд, нам гүм цэгээр хуваана',
    () async {
      // 40 секунд: тасралтгүй яриа, 12.0-12.4 ба 25.0-25.4 секундэд завсарлага
      final clip = Float32List.fromList([
        for (var i = 0; i < sampleRate * 40; i++) 0.3 * math.sin(i / 8),
      ]);
      for (final pause in [12.0, 25.0]) {
        clip.fillRange(
          (pause * sampleRate).round(),
          ((pause + 0.4) * sampleRate).round(),
          0,
        );
      }
      final parts = splitForTranscription(clip);
      expect(parts.fold<int>(0, (n, p) => n + p.length), clip.length);
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(14 * sampleRate));
      }
      // Эхний хуваалт завсарлага дээр таарна
      expect(parts.first.length / sampleRate, inInclusiveRange(12.0, 12.4));
      expect(splitForTranscription(Float32List(sampleRate * 5)).length, 1);

      // Хэсэг бүрийг тусад нь илгээж, хариуг нийлүүлнэ
      var calls = 0;
      final t = Transcriber(
        token: 'test-token',
        client: MockClient((request) async {
          calls++;
          expect(
            request.bodyBytes.length,
            lessThanOrEqualTo(44 + 14 * sampleRate * 2),
          );
          return http.Response.bytes(utf8.encode('хэсэг $calls.'), 200);
        }),
      );
      final result = await t.transcribe(clip);
      expect(calls, parts.length);
      expect(
        result.text,
        [for (var i = 1; i <= calls; i++) 'хэсэг $i.'].join(' '),
      );
    },
  );
}
