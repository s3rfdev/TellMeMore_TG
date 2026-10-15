import '../../core/localization/app_locale.dart';
import '../models/tg_chat.dart';

/// Разбор содержимого сообщений TDLib + детерминированные аватары.
/// Чистый Dart — используется в воркер-изоляте и в тестах.
class TdContent {
  TdContent._();

  static const palette = [
    0xFFE17076, 0xFF7BC862, 0xFFE5CA77, 0xFF65AADD,
    0xFFA695E7, 0xFFEE7AAE, 0xFF6EC9CB, 0xFFFAA774,
  ];

  static int colorFor(String key) {
    var hash = 0;
    for (final c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  static String initials(String title) {
    final words = title
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '#';
    if (words.length == 1) {
      final w = words.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  static bool isPhoto(Map<String, dynamic> msg) =>
      msg['content']?['@type'] == 'messagePhoto';

  static MessageKind messageKind(Map<String, dynamic> msg) {
    final type = msg['content']?['@type'] as String?;
    switch (type) {
      case 'messagePhoto':
        return MessageKind.image;
      case 'messageVideo':
      case 'messageVideoNote':
      case 'messageAnimation':
        return MessageKind.video;
      case 'messageVoiceNote':
        return MessageKind.voice;
      case 'messageAudio':
        return MessageKind.audio;
      case 'messageDocument':
        return MessageKind.document;
      default:
        return MessageKind.text;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _extractText(dynamic obj) {
    if (obj == null) return '';
    if (obj is String) return obj;
    if (obj is Map) {
      final t = obj['text'];
      if (t is String) return t;
      if (t is Map) return _extractText(t);
    }
    return '';
  }

  /// Текст для пузыря/превью (для медиа — подпись или тип).
  static String fullText(Map<String, dynamic> msg) {
    try {
      final content = msg['content'];
      if (content == null || content is! Map<String, dynamic>) return '';
      final isRu = I18n.instance.isRu;
      final type = content['@type'] as String?;
      switch (type) {
        case 'messageText':
          return _extractText(content['text']);
        case 'messagePhoto':
          final caption = _extractText(content['caption']);
          return caption.isEmpty ? (isRu ? 'Фотография' : 'Photo') : caption;
        case 'messageSticker':
          final emoji = content['sticker'] is Map ? (content['sticker']['emoji'] as String? ?? '') : '';
          final label = isRu ? 'Стикер' : 'Sticker';
          return emoji.isEmpty ? label : '$emoji $label';
        case 'messageAnimation':
          final caption = _extractText(content['caption']);
          return caption.isEmpty ? 'GIF' : caption;
        case 'messageVideo':
        case 'messageVideoNote':
          final caption = _extractText(content['caption']);
          return caption.isEmpty ? (isRu ? 'Видео' : 'Video') : caption;
        case 'messageVoiceNote':
          return isRu ? 'Голосовое сообщение' : 'Voice message';
        case 'messageAudio':
          final title = content['audio'] is Map ? (content['audio']['title'] as String? ?? '') : '';
          return title.isEmpty ? (isRu ? 'Аудиозапись' : 'Audio') : title;
        case 'messageDocument':
          final doc = content['document'] is Map ? content['document'] : null;
          return (doc?['file_name'] as String?) ?? (isRu ? 'Файл' : 'File');
        case 'messageAnimatedEmoji':
          final emoji = content['animated_emoji'] is Map ? (content['animated_emoji']['emoji'] as String?) : null;
          return emoji ?? '✨';
        case 'messageDice':
          final emoji = content['dice'] is Map ? (content['dice']['emoji'] as String?) : null;
          return emoji ?? '🎲';
        case 'messagePoll':
          final poll = content['poll'] is Map ? content['poll'] : null;
          final q = _extractText(poll?['question']);
          return '📊 ${q.isNotEmpty ? q : (isRu ? 'Опрос' : 'Poll')}';
        case 'messageLocation':
          return isRu ? '📍 Геолокация' : '📍 Location';
        case 'messageContact':
          return isRu ? '👤 Контакт' : '👤 Contact';
        case 'messageCall':
          return isRu ? '📞 Звонок' : '📞 Call';
        case 'messagePinMessage':
          return isRu ? '📌 Закрепленное сообщение' : '📌 Pinned message';
        case 'messageChatAddMembers':
          return isRu ? 'Пользователь добавлен в чат' : 'User added to chat';
        case 'messageChatJoinByLink':
          return isRu ? 'Пользователь вступил по ссылке' : 'User joined via link';
        case 'messageChatDeleteMember':
          return isRu ? 'Пользователь покинул чат' : 'User left chat';
        default:
          final t = _extractText(content['text']);
          if (t.isNotEmpty) return t;
          final c = _extractText(content['caption']);
          if (c.isNotEmpty) return c;
          return isRu ? 'Сообщение' : 'Message';
      }
    } catch (_) {
      return I18n.instance.isRu ? 'Сообщение' : 'Message';
    }
  }
}
