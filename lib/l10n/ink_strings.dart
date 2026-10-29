import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'catalog.dart';

class InkLanguage {
  const InkLanguage(this.code, this.name);
  final String code, name;
}

/// Bundled, synchronous translations also cover messages in older save files.
class InkStrings {
  const InkStrings(this.code);
  final String code;
  static const fontFallbacks = ['InkArabic', 'InkSC', 'InkJP', 'InkKR'];
  List<String> get fonts => switch (code) {
    'ja' => ['InkJP', 'InkSC', 'InkKR', 'InkArabic'],
    'ko' => ['InkKR', 'InkSC', 'InkJP', 'InkArabic'],
    _ => fontFallbacks,
  };
  static const languages = [
    InkLanguage('tr', 'Türkçe'),
    InkLanguage('en', 'English'),
    InkLanguage('de', 'Deutsch'),
    InkLanguage('fr', 'Français'),
    InkLanguage('es', 'Español'),
    InkLanguage('pt', 'Português'),
    InkLanguage('ru', 'Русский'),
    InkLanguage('zh', '简体中文'),
    InkLanguage('ja', '日本語'),
    InkLanguage('ko', '한국어'),
    InkLanguage('ar', 'العربية'),
    InkLanguage('id', 'Bahasa Indonesia'),
  ];
  static String resolve(String? code) {
    final base = code?.replaceAll('_', '-').split('-').first.toLowerCase();
    return languages.any((l) => l.code == base) ? base! : 'en';
  }

  static InkStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InkLocale>()?.strings ??
      const InkStrings('en');
  String t(String source, [Map<String, Object> arguments = const {}]) {
    final language = languages.indexWhere((l) => l.code == resolve(code));
    var value = inkCatalog[source]?[language] ?? source;
    for (final entry in arguments.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String distance(double value) =>
      NumberFormat('0.0', resolve(code)).format(value);
  double tracking(double spacing) => code == 'ar' ? 0 : spacing;
}

class InkLocale extends InheritedWidget {
  const InkLocale({
    super.key,
    required this.strings,
    this.onChanged,
    required super.child,
  });
  final InkStrings strings;
  final ValueChanged<String>? onChanged;
  static InkLocale? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InkLocale>();
  @override
  bool updateShouldNotify(InkLocale oldWidget) =>
      oldWidget.strings.code != strings.code;
}
