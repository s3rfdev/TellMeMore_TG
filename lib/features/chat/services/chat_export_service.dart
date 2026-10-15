import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/app_locale.dart';
import '../../../data/models/tg_chat.dart';
import '../../ai_copilot/models/contact_dossier.dart';

enum ExportContentType {
  advisorProfile,
  chatHistory,
  fullArchive,
}

enum ExportFormat {
  text,
  json,
}

class ChatExportService {
  ChatExportService._();
  static final ChatExportService instance = ChatExportService._();

  /// Форматирует досье собеседника специально для ассистента звонков / собеседований (AI Advisor)
  String formatAdvisorProfile(TgChat chat, ContactDossier dossier) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final isRu = I18n.instance.isRu;
    final buffer = StringBuffer();
    buffer.writeln('================================================================================');
    buffer.writeln(isRu
        ? '📋 ПРОФИЛЬ СОБЕСЕДНИКА ДЛЯ AI-ЭДВАЙЗЕРА / ПОМОЩНИКА ДЛЯ ЗВОНКОВ'
        : '📋 CONTACT PROFILE FOR AI ADVISOR / CALL ASSISTANT');
    buffer.writeln('================================================================================');
    buffer.writeln('${isRu ? "👤 Собеседник" : "👤 Contact"}: ${chat.title}');
    if (chat.headerSubtitle.isNotEmpty) {
      buffer.writeln('${isRu ? "ℹ️ Статус / Роль" : "ℹ️ Status / Role"}: ${chat.headerSubtitle}');
    }
    buffer.writeln('${isRu ? "🆔 ID чата" : "🆔 Chat ID"}: ${chat.id}');
    buffer.writeln('${isRu ? "📅 Дата выгрузки" : "📅 Export Date"}: $dateStr');
    buffer.writeln('');

    buffer.writeln(isRu
        ? '🎯 ЦЕЛЬ ОБЩЕНИЯ (СТРАТЕГИЧЕСКАЯ ЗАДАЧА):'
        : '🎯 GOAL (STRATEGIC OBJECTIVE):');
    buffer.writeln(dossier.goal.isNotEmpty
        ? dossier.goal
        : (isRu ? 'Установить контакт и выявить потребности' : 'Establish contact and identify needs'));
    buffer.writeln('');

    buffer.writeln(isRu
        ? '🧠 ПСИХОТИП И СТИЛЬ МЫШЛЕНИЯ:'
        : '🧠 PSYCHOTYPE & COGNITIVE STYLE:');
    buffer.writeln(dossier.psychotype.isNotEmpty
        ? dossier.psychotype
        : (isRu ? 'Уравновешенный, прагматичный стиль' : 'Balanced, pragmatic style'));
    buffer.writeln('');

    buffer.writeln(isRu
        ? '🗣 РЕКОМЕНДУЕМЫЙ ТОН ОБЩЕНИЯ:'
        : '🗣 RECOMMENDED TONE OF VOICE:');
    buffer.writeln(dossier.tone.isNotEmpty
        ? dossier.tone
        : (isRu ? 'Деловой и вежливый' : 'Professional and polite'));
    buffer.writeln('');

    buffer.writeln(isRu
        ? '📌 КЛЮЧЕВЫЕ ФАКТЫ И CRM-ПАМЯТЬ:'
        : '📌 KEY FACTS & CRM MEMORY:');
    if (dossier.facts.isEmpty) {
      buffer.writeln(isRu ? '• Нет зафиксированных фактов' : '• No recorded facts');
    } else {
      for (final fact in dossier.facts) {
        buffer.writeln('• $fact');
      }
    }
    buffer.writeln('');

    buffer.writeln(isRu
        ? '📋 ВЫЖИМКА ПРЕДЫДУЩЕГО ДИАЛОГА:'
        : '📋 CONVERSATION SUMMARY:');
    buffer.writeln(dossier.summary.isNotEmpty
        ? dossier.summary
        : (isRu ? 'Диалог только начат' : 'Conversation just started'));
    buffer.writeln('');

    buffer.writeln(isRu
        ? '💡 ИНСТРУКЦИЯ ДЛЯ АССИСТЕНТА ВО ВРЕМЯ РАЗГОВОРА (LIVE PROMPT):'
        : '💡 LIVE PROMPT FOR CALL ASSISTANT:');
    if (isRu) {
      buffer.writeln('1. Главная цель: "${dossier.goal}". Не позволяйте собеседнику увести разговор в сторону.');
      buffer.writeln('2. Особенности психотипа: ${dossier.psychotype}. Подстраивайте аргументы под этот тип.');
      buffer.writeln('3. Тональность: ${dossier.tone}.');
      buffer.writeln('4. Если собеседник задает неожиданные вопросы, сверяйтесь с разделом «Ключевые факты».');
    } else {
      buffer.writeln('1. Main Goal: "${dossier.goal}". Keep the conversation focused on this objective.');
      buffer.writeln('2. Psychotype: ${dossier.psychotype}. Tailor your arguments accordingly.');
      buffer.writeln('3. Tone: ${dossier.tone}.');
      buffer.writeln('4. Consult Key Facts if unexpected questions arise.');
    }
    buffer.writeln('================================================================================');

    return buffer.toString();
  }

  /// Форматирует текстовую историю переписки чата
  String formatChatHistory(TgChat chat, List<TgMessage> messages) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final isRu = I18n.instance.isRu;

    final buffer = StringBuffer();
    buffer.writeln('================================================================================');
    buffer.writeln('${isRu ? "💬 ИСТОРИЯ ПЕРЕПИСКИ" : "💬 CHAT HISTORY"}: ${chat.title}');
    buffer.writeln('${isRu ? "📅 Дата выгрузки" : "📅 Export Date"}: $dateStr');
    buffer.writeln('${isRu ? "📊 Всего сообщений" : "📊 Total Messages"}: ${messages.length}');
    buffer.writeln('================================================================================');
    buffer.writeln('');

    if (messages.isEmpty) {
      buffer.writeln(isRu ? '(История сообщений пуста)' : '(Message history is empty)');
      return buffer.toString();
    }

    for (final msg in messages) {
      if (msg.kind == MessageKind.unreadDivider) continue;

      if (msg.kind == MessageKind.date) {
        buffer.writeln('--- ${msg.text} ---');
        continue;
      }

      final sender = msg.outgoing
          ? (isRu ? 'Вы' : 'You')
          : (msg.replySenderName.isNotEmpty ? msg.replySenderName : chat.title);
      final time = msg.time.isNotEmpty ? '[${msg.time}]' : '';

      String content = msg.text;
      if (msg.kind == MessageKind.voice) {
        content = isRu
            ? '[🎤 Голосовое сообщение, ${msg.duration} сек${msg.text.isNotEmpty ? ": ${msg.text}" : ""}]'
            : '[🎤 Voice message, ${msg.duration} sec${msg.text.isNotEmpty ? ": ${msg.text}" : ""}]';
      } else if (msg.kind == MessageKind.image) {
        content = isRu
            ? '[🖼 Изображение${msg.fileName.isNotEmpty ? ": ${msg.fileName}" : ""}${msg.text.isNotEmpty ? " — ${msg.text}" : ""}]'
            : '[🖼 Photo${msg.fileName.isNotEmpty ? ": ${msg.fileName}" : ""}${msg.text.isNotEmpty ? " — ${msg.text}" : ""}]';
      } else if (msg.kind == MessageKind.video) {
        content = isRu
            ? '[🎬 Видео, ${msg.duration} сек${msg.text.isNotEmpty ? ": ${msg.text}" : ""}]'
            : '[🎬 Video, ${msg.duration} sec${msg.text.isNotEmpty ? ": ${msg.text}" : ""}]';
      } else if (msg.kind == MessageKind.document) {
        content = isRu
            ? '[📎 Документ: ${msg.fileName} (${msg.fileSize})${msg.text.isNotEmpty ? " — ${msg.text}" : ""}]'
            : '[📎 Document: ${msg.fileName} (${msg.fileSize})${msg.text.isNotEmpty ? " — ${msg.text}" : ""}]';
      }

      if (msg.replyText.isNotEmpty) {
        buffer.writeln('$time $sender (${isRu ? "в ответ на" : "reply to"} "${msg.replyText}"): $content');
      } else {
        buffer.writeln('$time $sender: $content');
      }
    }

    return buffer.toString();
  }

  /// Полный объединенный архив: Досье для эдвайзера + полная переписка
  String formatFullArchive(TgChat chat, ContactDossier dossier, List<TgMessage> messages) {
    final buffer = StringBuffer();
    buffer.writeln(formatAdvisorProfile(chat, dossier));
    buffer.writeln('');
    buffer.writeln(formatChatHistory(chat, messages));
    return buffer.toString();
  }

  /// Экспорт в JSON формат (для программных интеграций и эдвайзеров с REST/JSON входом)
  String exportToJsonString(
    TgChat chat,
    ContactDossier dossier,
    List<TgMessage> messages, {
    ExportContentType type = ExportContentType.fullArchive,
  }) {
    final now = DateTime.now();

    final data = <String, dynamic>{
      'export_metadata': {
        'source': 'TG Answer AI',
        'version': '1.0',
        'exported_at': now.toIso8601String(),
        'type': type.name,
      },
      'contact': {
        'id': chat.id,
        'title': chat.title,
        'subtitle': chat.headerSubtitle,
        'is_verified': chat.verified,
      },
    };

    if (type == ExportContentType.advisorProfile || type == ExportContentType.fullArchive) {
      data['advisor_profile'] = {
        'goal': dossier.goal,
        'psychotype': dossier.psychotype,
        'tone': dossier.tone,
        'crm_facts': dossier.facts,
        'summary': dossier.summary,
        'last_analyzed': dossier.lastAnalyzed?.toIso8601String(),
      };
    }

    if (type == ExportContentType.chatHistory || type == ExportContentType.fullArchive) {
      data['messages'] = messages
          .where((m) => m.kind != MessageKind.unreadDivider)
          .map((m) => {
                'id': m.id,
                'kind': m.kind.name,
                'time': m.time,
                'is_outgoing': m.outgoing,
                'sender': m.outgoing ? (I18n.instance.isRu ? 'Вы' : 'You') : (m.replySenderName.isNotEmpty ? m.replySenderName : chat.title),
                'text': m.text,
                'reply_to': m.replyText.isNotEmpty ? m.replyText : null,
                'duration': m.duration > 0 ? m.duration : null,
                'file_name': m.fileName.isNotEmpty ? m.fileName : null,
              })
          .toList();
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Получить итоговую строку для предпросмотра/экспорта в зависимости от типа и формата
  String generateExportText({
    required TgChat chat,
    required ContactDossier dossier,
    required List<TgMessage> messages,
    required ExportContentType type,
    required ExportFormat format,
  }) {
    if (format == ExportFormat.json) {
      return exportToJsonString(chat, dossier, messages, type: type);
    }

    switch (type) {
      case ExportContentType.advisorProfile:
        return formatAdvisorProfile(chat, dossier);
      case ExportContentType.chatHistory:
        return formatChatHistory(chat, messages);
      case ExportContentType.fullArchive:
        return formatFullArchive(chat, dossier, messages);
    }
  }

  /// Копирует содержимое в буфер обмена системы
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Сохраняет файл на диск (в директорию Downloads или Documents)
  Future<String> saveToFile({
    required String fileName,
    required String content,
  }) async {
    Directory? exportDir;
    try {
      exportDir = await getDownloadsDirectory();
    } catch (_) {}

    if (exportDir == null) {
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final downloads = Directory('$home/Downloads');
          if (downloads.existsSync()) {
            exportDir = downloads;
          }
        }
      } catch (_) {}
    }

    if (exportDir == null) {
      try {
        exportDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }

    exportDir ??= Directory.current;

    final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${exportDir.path}/$sanitizedName';
    final file = File(filePath);

    await file.writeAsString(content, flush: true);
    return file.path;
  }
}
