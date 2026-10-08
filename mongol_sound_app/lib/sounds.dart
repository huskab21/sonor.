import 'dart:convert';

import 'package:flutter/material.dart';

const int sampleRate = 16000;
const int yamnetSamples = 15600; // YAMNet-ийн оролт (0.975 сек)
const int nameSamples = 24000; // нэр таних загварын оролт (1.5 сек)
const int hopSamples = 4000; // 0.25 сек тутам шалгана
const Duration cooldown = Duration(milliseconds: 2500);
const Duration quietCooldown = Duration(
  seconds: 30,
); // тайлбар, чанга чимээний дохио
const String loudSoundId = 'loud';

enum SoundCategory {
  alarms('Дохиолол'),
  home('Гэр ахуй'),
  people('Хүн'),
  animals('Амьтан');

  const SoundCategory(this.title);
  final String title;
}

/// YAMNet-ийн ангиллуудыг Монгол үйл явдал руу буулгана.
/// threshold: 0-1 хооронд, бага бол амархан танина (буруу дохио ихэснэ).
class SoundEvent {
  const SoundEvent(
    this.id,
    this.category,
    this.icon,
    this.label,
    this.classes,
    this.threshold, {
    this.urgent = false,
    this.defaultOn = true,
  });
  final String id;
  final SoundCategory category;
  final IconData icon;
  final String label;
  final List<String> classes;
  final double threshold;
  final bool urgent; // аюултай чимээ: илүү хүчтэй анхааруулна
  final bool defaultOn;
}

const List<SoundEvent> soundEvents = [
  SoundEvent(
    'fire',
    SoundCategory.alarms,
    Icons.local_fire_department,
    'Гал, утааны дохиолол',
    ['Fire alarm', 'Smoke detector, smoke alarm'],
    0.30,
    urgent: true,
  ),
  SoundEvent(
    'siren',
    SoundCategory.alarms,
    Icons.emergency,
    'Сирен',
    [
      'Siren',
      'Civil defense siren',
      'Police car (siren)',
      'Ambulance (siren)',
      'Fire engine, fire truck (siren)',
    ],
    0.35,
    urgent: true,
  ),
  SoundEvent(
    'car_alarm',
    SoundCategory.alarms,
    Icons.car_crash,
    'Машины дохиолол',
    ['Car alarm'],
    0.35,
  ),
  SoundEvent('alarm_clock', SoundCategory.alarms, Icons.alarm, 'Сэрүүлэг', [
    'Alarm clock',
    'Alarm',
  ], 0.35),
  // YAMNet-ийн ангилалгүй: дууны түвшин удаан өндөр байвал хөдөлгүүр өөрөө дохио өгнө
  SoundEvent(
    loudSoundId,
    SoundCategory.alarms,
    Icons.volume_up,
    'Удаан үргэлжилсэн чанга чимээ',
    [],
    1.0,
  ),
  SoundEvent(
    'doorbell',
    SoundCategory.home,
    Icons.notifications_active,
    'Хаалганы хонх',
    ['Doorbell', 'Ding-dong'],
    0.30,
  ),
  SoundEvent('knock', SoundCategory.home, Icons.back_hand, 'Хаалга тогших', [
    'Knock',
  ], 0.30),
  SoundEvent(
    'glass',
    SoundCategory.home,
    Icons.broken_image,
    'Шил, аяга хагарах',
    ['Shatter', 'Glass'],
    0.30,
    urgent: true,
  ),
  SoundEvent(
    'door',
    SoundCategory.home,
    Icons.door_front_door,
    'Хаалга хаагдах, онгойх',
    ['Door', 'Slam', 'Sliding door'],
    0.35,
  ),
  SoundEvent(
    'phone',
    SoundCategory.home,
    Icons.phone_in_talk,
    'Утас дуугарах',
    ['Telephone bell ringing', 'Ringtone'],
    0.35,
  ),
  SoundEvent(
    'car_horn',
    SoundCategory.home,
    Icons.directions_car,
    'Машины дуут дохио',
    ['Vehicle horn, car horn, honking', 'Air horn, truck horn'],
    0.35,
  ),
  SoundEvent(
    'kettle',
    SoundCategory.home,
    Icons.coffee_maker,
    'Данх буцлах',
    ['Steam whistle', 'Boiling'],
    0.35,
    defaultOn: false,
  ),
  SoundEvent(
    'water',
    SoundCategory.home,
    Icons.water_drop,
    'Ус гоожих',
    ['Water tap, faucet', 'Sink (filling or washing)'],
    0.40,
    defaultOn: false,
  ),
  SoundEvent('baby', SoundCategory.people, Icons.child_care, 'Хүүхэд уйлах', [
    'Baby cry, infant cry',
    'Crying, sobbing',
  ], 0.35),
  SoundEvent(
    'shout',
    SoundCategory.people,
    Icons.campaign,
    'Хашгирах',
    ['Shout', 'Yell', 'Screaming'],
    0.40,
    urgent: true,
  ),
  SoundEvent(
    'cough',
    SoundCategory.people,
    Icons.sick,
    'Ханиах',
    ['Cough'],
    0.40,
    defaultOn: false,
  ),
  SoundEvent('dog', SoundCategory.animals, Icons.pets, 'Нохой хуцах', [
    'Dog',
    'Bark',
  ], 0.40),
  SoundEvent('cat', SoundCategory.animals, Icons.cruelty_free, 'Муур мяавах', [
    'Cat',
    'Meow',
  ], 0.40),
];

/// Хэрэглэгчийн өөрөө нэмж, бичлэгээр заасан чимээ.
class CustomSound {
  const CustomSound(this.id, this.label);
  final String id;
  final String label;
}

const IconData customSoundIcon = Icons.hearing;

/// Каталогт байхгүй ч YAMNet таньдаг түгээмэл чимээнүүд. Ийм чимээ гарвал дохио өгөхгүй,
/// харин түүхэнд "... шиг чимээ" гэж тэмдэглэнэ.
const Map<String, String> describedClasses = {
  'Music': 'Хөгжим',
  'Singing': 'Дуулах',
  'Laughter': 'Инээд',
  'Whistling': 'Исгэрэх',
  'Snoring': 'Хурхирах',
  'Sneeze': 'Найтаах',
  'Walk, footsteps': 'Хөлийн чимээ',
  'Clapping': 'Алга таших',
  'Applause': 'Алга ташилт',
  'Bird': 'Шувуу',
  'Horse': 'Морь',
  'Sheep': 'Хонь',
  'Goat': 'Ямаа',
  'Guitar': 'Гитар',
  'Piano': 'Төгөлдөр хуур',
  'Drum': 'Бөмбөр',
  'Bell': 'Хонх',
  'Wind': 'Салхи',
  'Thunder': 'Аянга',
  'Rain': 'Бороо',
  'Engine': 'Мотор',
  'Car': 'Машин',
  'Motorcycle': 'Мотоцикл',
  'Train': 'Галт тэрэг',
  'Aircraft': 'Онгоц',
  'Helicopter': 'Нисдэг тэрэг',
  'Dishes, pots, and pans': 'Аяга таваг',
  'Frying (food)': 'Хоол шарах',
  'Microwave oven': 'Богино долгионы зуух',
  'Blender': 'Холигч',
  'Hair dryer': 'Үс хатаагч',
  'Toilet flush': 'Суултуур',
  'Vacuum cleaner': 'Тоос сорогч',
  'Keys jangling': 'Түлхүүр',
  'Electric shaver, electric razor': 'Сахлын машин',
  'Typing': 'Компьютерын гар',
  'Mechanical fan': 'Сэнс',
  'Air conditioning': 'Агааржуулагч',
  'Printer': 'Хэвлэгч',
  'Hammer': 'Алх',
  'Sawing': 'Хөрөө',
  'Drill': 'Өрөм',
  'Explosion': 'Дэлбэрэлт',
  'Fireworks': 'Салют',
  'Beep, bleep': 'Дохионы дуу',
  'Tick-tock': 'Цаг',
  'Television': 'Зурагт',
  'Radio': 'Радио',
};
const double describeThreshold = 0.5;

/// Хүний яриаг илтгэх YAMNet-ийн ангиллууд. Нэрийн дохиог зөвхөн эдгээр сонсогдсон үед өгнө.
const List<String> speechClasses = [
  'Speech',
  'Child speech, kid speaking',
  'Conversation',
  'Narration, monologue',
  'Shout',
  'Yell',
  'Children shouting',
  'Whispering',
];

class Detection {
  Detection(
    this.icon,
    this.label,
    this.score, {
    this.isName = false,
    this.urgent = false,
    this.guess = false,
  }) : time = DateTime.now();

  /// Тайлбар төдий тэмдэглэл ("... шиг чимээ"): чичиргээ, мэдэгдэлгүй, зөвхөн түүхэнд орно.
  final bool guess;
  final IconData icon;
  final String label;
  final double score;
  final bool isName;
  final bool urgent;
  final DateTime time;
}

/// yamnet_class_map.csv -> ангиллын нэрс (мөрийн дугаар = ангиллын индекс).
List<String> parseClassMap(String csv) {
  final names = <String>[];
  for (final line in const LineSplitter().convert(csv).skip(1)) {
    final first = line.indexOf(',');
    final second = line.indexOf(',', first + 1);
    if (first < 0 || second < 0) continue;
    var name = line.substring(second + 1).trim();
    if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
      name = name.substring(1, name.length - 1);
    }
    names.add(name);
  }
  return names;
}
