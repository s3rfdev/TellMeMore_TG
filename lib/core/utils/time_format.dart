/// Форматирование времени в стиле Telegram («8:14 PM», «Today»).
String formatTime(int unix) {
  if (unix <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$h:$mm ${dt.hour < 12 ? 'AM' : 'PM'}';
}

String dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
}
