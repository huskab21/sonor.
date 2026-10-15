import 'package:flutter/material.dart';

import 'glass.dart';

/// Монгол дохионы хэлний хурууны цагаан толгой: кирилл үсэг -> зургийн файлын нэр.
/// Зургууд `assets/signs/`-д байна (эх: «Диф Влог»-ийн цагаан толгойн зурагт хуудас).
const Map<String, String> signFiles = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'ye',
  'ё': 'yo',
  'ж': 'j',
  'з': 'z',
  'и': 'i',
  'й': 'ii',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'ө': 'oe',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ү': 'ue',
  'ф': 'f',
  'х': 'kh',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'shch',
  'ъ': 'hard',
  'ы': 'y',
  'ь': 'soft',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

/// Гарын үсгүүд цагаан толгойн дарааллаар.
const String signAlphabet = 'абвгдеёжзийклмноөпрстуүфхцчшщъыьэюя';

/// Үсгийн дохионы зураг. Үсэг биш тэмдэгтэд null.
String? signAsset(String char) {
  final file = signFiles[char.toLowerCase()];
  return file == null ? null : 'assets/signs/$file.png';
}

/// Аппын бичвэрийг дохионы үсгээр харуулах горим асаалттай эсэхийг доош дамжуулна.
class SignScope extends InheritedWidget {
  const SignScope({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SignScope>()?.enabled ?? false;

  @override
  bool updateShouldNotify(SignScope old) => old.enabled != enabled;
}

/// Аппын бичвэр. Энгийн үед [Text]-тэй адил; дохионы горимд кирилл үсэг бүрийг
/// хурууны дохионы зургаар солино. Тоо, цэг таслал, латин үсэг хэвээр үлдэнэ.
class SText extends StatelessWidget {
  const SText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines; // давбал «…»-ээр таслана

  @override
  Widget build(BuildContext context) {
    if (!SignScope.of(context)) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }
    final base = DefaultTextStyle.of(context).style.merge(style);
    // Гарын хэлбэр жижиг үсгийн хэмжээнд танигдахгүй тул бичвэрээс том зурна
    final size = ((base.fontSize ?? 14) * 1.6).clamp(22.0, 64.0);
    final spans = <InlineSpan>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) return;
      spans.add(TextSpan(text: plain.toString()));
      plain.clear();
    }

    final ink = base.color ?? inkOf(context);
    for (final rune in data.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ') {
        // Үг хоорондын зай: гарын дүрсийн хагастай тэнцэх өргөн
        flush();
        spans.add(WidgetSpan(child: SizedBox(width: size * 0.55)));
        continue;
      }
      final asset = signAsset(char);
      if (asset == null) {
        plain.write(char);
        continue;
      }
      flush();
      // Гарын дохио, хажууд нь жижгээр кирилл үсэг
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Image.asset(asset, width: size, height: size),
                Text(
                  char,
                  style: TextStyle(
                    fontSize: (size * 0.36).clamp(9.0, 16.0),
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    flush();
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      semanticsLabel: data,
    );
  }
}

/// Дохионы үсгийн гар: 35 үсэг, зай, арилгах. Товч бүр дээр гарын дохио, буланд нь
/// жижгээр кирилл үсэг.
class SignKeyboard extends StatelessWidget {
  const SignKeyboard({
    super.key,
    required this.onChar,
    required this.onBackspace,
  });
  final ValueChanged<String> onChar;
  final VoidCallback onBackspace;

  Widget _key(BuildContext context, Widget child, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: inkOf(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final faint = faintOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final rune in signAlphabet.runes)
              _key(
                context,
                Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          signAsset(String.fromCharCode(rune))!,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 1,
                      child: Text(
                        String.fromCharCode(rune).toUpperCase(),
                        style: TextStyle(fontSize: 10, color: faint),
                      ),
                    ),
                  ],
                ),
                () => onChar(String.fromCharCode(rune)),
              ),
          ],
        ),
        SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _key(
                  context,
                  const Center(child: Icon(Icons.space_bar)),
                  () => onChar(' '),
                ),
              ),
              Expanded(
                flex: 2,
                child: _key(
                  context,
                  const Center(child: Icon(Icons.backspace_outlined)),
                  onBackspace,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Нүүрний дээд булангийн солигч: «МН» (монгол бичвэр) ба дохионы хурууны үсэг.
/// Өөрөө үргэлж энгийн үсэг, дүрсээр харагдана: аль ч горимоос буцаж сольж болно.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.sign,
    required this.onChanged,
  });
  final bool sign;
  final ValueChanged<bool> onChanged;

  Widget _side(BuildContext context, bool value, Widget child, String label) {
    final selected = sign == value;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: selected ? accentGradient : null,
          ),
          child: IconTheme.merge(
            data: IconThemeData(
              size: 20,
              color: selected ? Colors.white : inkOf(context),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : inkOf(context),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _side(context, false, const Text('МН'), 'Монгол бичвэр'),
          _side(
            context,
            true,
            const Icon(Icons.sign_language),
            'Дохионы хэлний үсэг',
          ),
        ],
      ),
    );
  }
}
