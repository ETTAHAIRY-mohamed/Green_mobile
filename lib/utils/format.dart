/// Formats d'affichage à la française (virgule décimale, espace insécable).
library;

const String _nbsp = ' ';

/// `0.964` → « 96 % » ; une valeur > 0 mais < 0,5 % s'affiche « < 1 % ».
String percentLabel(double probability) {
  final n = (probability * 100).round();
  if (probability > 0 && n == 0) return '<$_nbsp' '1$_nbsp%';
  return '$n$_nbsp%';
}

/// `2.3141` → « 2,31 ms » (2 décimales sous 10 ms, sinon 1).
String msLabel(double ms) {
  final digits = ms < 10 ? 2 : 1;
  return '${ms.toStringAsFixed(digits).replaceAll('.', ',')}$_nbsp' 'ms';
}

/// `0.952` → « 95,2 % ».
String accuracyLabel(double v) =>
    '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')}$_nbsp%';

/// `649048` → « 649 kB » (kB = 1000 octets, comme dans model_info.json).
String sizeLabel(int bytes) => '${(bytes / 1000).round()}$_nbsp' 'kB';

const List<String> _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// `14:05` (24 h, deux chiffres).
String timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// `22 novembre` ; l'année est ajoutée si elle diffère de celle de [now].
String dateLabel(DateTime d, {required DateTime now}) {
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}

/// « Aujourd'hui », « Hier », sinon la date (`22 novembre`).
String dayLabel(DateTime d, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Hier';
  return dateLabel(d, now: now);
}
