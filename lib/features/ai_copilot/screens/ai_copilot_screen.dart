import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/utils/link_handler.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../models/ai_settings_model.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/ai_model_service.dart';
import '../services/copilot_session_store.dart';
import '../services/image_description_service.dart';
import '../services/voice_transcription_service.dart';

/// Экран активного чата с выбранным Copilot-агентом.
class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isLoading = false;
  bool _summaryExpanded = false;
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _voicePath;
  String? _attachedFilePath;
  String? _attachedFileName;
  bool _isAttachedImage = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          TgToast.show(
            context,
            tr('no_mic_permission'),
            icon: Icons.mic_off_rounded,
          );
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/copilot_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
        _voicePath = path;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        TgToast.show(
          context,
          tr('recording_error', {'error': e.toString()}),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _stopVoice({required bool send, required CopilotSession session}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final finalPath = path ?? _voicePath;
    final sec = _recordSeconds;

    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
      _voicePath = null;
    });

    if (send && finalPath != null && (sec > 0 || (File(finalPath).existsSync() && File(finalPath).lengthSync() > 1000))) {
      final isRu = I18n.instance.isRu;
      if (mounted) {
        TgToast.show(
          context,
          isRu ? '🎤 Распознавание речи...' : '🎤 Transcribing speech...',
          icon: Icons.mic_rounded,
        );
      }

      final transcription = await VoiceTranscriptionService.instance.transcribeVoiceFile(
        filePath: finalPath,
        durationSeconds: sec,
      );

      if (transcription.isNotEmpty && !transcription.startsWith('[')) {
        _sendMessage(session, transcription);
      } else {
        if (mounted) {
          TgToast.show(
            context,
            isRu
                ? 'Не удалось распознать речь'
                : 'Could not transcribe speech',
            icon: Icons.warning_amber_rounded,
          );
        }
      }
    }
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'webp', 'gif',
          'pdf', 'txt', 'csv', 'json', 'md', 'doc', 'docx',
        ],
      );
      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final name = result.first.name;
        final ext = path.toLowerCase().split('.').last;
        final isImg = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
        setState(() {
          _attachedFilePath = path;
          _attachedFileName = name;
          _isAttachedImage = isImg;
        });
      }
    } catch (e) {
      if (mounted) TgToast.show(context, 'Ошибка выбора файла: $e');
    }
  }

  void _sendMessage(
    CopilotSession session,
    String text, {
    String? attachmentPath,
    String? attachmentName,
    bool? isImageAttachment,
  }) async {
    final attachedPath = attachmentPath ?? _attachedFilePath;
    final attachedName = attachmentName ?? _attachedFileName;
    final isImg = isImageAttachment ?? _isAttachedImage;
    final isRu = I18n.instance.isRu;

    var query = text.trim();
    if (query.isEmpty) {
      if (attachedPath != null) {
        query = isImg
            ? (isRu ? 'Опиши это изображение и ответь на ключевые вопросы по нему.' : 'Describe this image and analyze its key details.')
            : (isRu ? 'Проанализируй прикрепленный документ.' : 'Analyze this attached document.');
      } else {
        return;
      }
    }

    _controller.clear();
    setState(() {
      _attachedFilePath = null;
      _attachedFileName = null;
      _isAttachedImage = false;
      _isLoading = true;
    });

    final userMsg = CopilotMessage(
      text: query,
      isUser: true,
      attachmentPath: attachedPath,
      attachmentName: attachedName,
      isImageAttachment: isImg,
    );

    CopilotSessionStore.instance.addMessage(session.id, userMsg);
    _scrollToBottom();

    // Читаем содержимое неграфических файлов при необходимости
    String effectiveQuery = query;
    if (attachedPath != null && !isImg) {
      try {
        final f = File(attachedPath);
        if (f.existsSync()) {
          final len = f.lengthSync();
          if (len < 64000) {
            final content = await f.readAsString();
            effectiveQuery = '[Файл: $attachedName]\n```\n$content\n```\n\n$query';
          } else {
            effectiveQuery = '[Файл: $attachedName (размер: ${len ~/ 1024} КБ)]\n\n$query';
          }
        }
      } catch (_) {}
    }

    // Проверка автокомпрессии до запроса
    final settings = AiSettingsStore.instance.settings.value;
    final compressedBefore = CopilotSessionStore.instance.checkAndAutoCompress(session.id, settings);
    if (compressedBefore && mounted) {
      TgToast.show(
        context,
        isRu
            ? '🗜️ Автокомпрессия сработала: контекст сжат по объёму'
            : '🗜️ Auto-compression triggered: context compressed',
      );
    }

    // Собираем историю диалога с Копилотом для multi-turn контекста (исключая текущее только что добавленное сообщение)
    final conversationHistory = <Map<String, String>>[];
    for (final m in session.messages) {
      if (identical(m, userMsg)) continue;
      conversationHistory.add({
        'role': m.isUser ? 'user' : 'model',
        'content': m.text,
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    String reply;
    String? tool;
    String? output;

    final lower = query.toLowerCase();
    TgChat? matchedChat;

    // 1. Поиск чата, связанного с сессией или упоминаемого в запросе
    if (session.id.startsWith('contact_')) {
      final cId = session.id.replaceFirst('contact_', '');
      final currentAcc = AccountManager.instance.currentAccount.value;
      final chats = [
        ...TdlibService.instance.chats.value,
        ...AccountManager.instance.getChats(currentAcc.id),
      ];
      final found = chats.where((c) => c.id == cId).toList();
      if (found.isNotEmpty) matchedChat = found.first;
    }

    if (matchedChat == null) {
      final currentAcc = AccountManager.instance.currentAccount.value;
      final chats = [
        ...TdlibService.instance.chats.value,
        ...AccountManager.instance.getChats(currentAcc.id),
      ];
      for (final c in chats) {
        if (c.title.isNotEmpty && lower.contains(c.title.toLowerCase())) {
          matchedChat = c;
          break;
        }
      }
      if (matchedChat == null &&
          (lower.contains('чат') ||
              lower.contains('диалог') ||
              lower.contains('переписк') ||
              lower.contains('chat') ||
              lower.contains('conversation'))) {
        final activeId = AppState.selectedChatId.value;
        final found = chats.where((c) => c.id == activeId).toList();
        if (found.isNotEmpty) matchedChat = found.first;
      }
    }

    // Системный промпт (из сессии + из настроек чата, если есть)
    String effectivePrompt = session.systemPrompt.trim();
    if (matchedChat != null) {
      final chatDossier = ContactDossierStore.instance.getDossier(matchedChat.id).value;
      if (chatDossier.systemPrompt.isNotEmpty) {
        effectivePrompt = effectivePrompt.isNotEmpty
            ? '$effectivePrompt\n\n${chatDossier.systemPrompt}'
            : chatDossier.systemPrompt;
      }
    }

    if (matchedChat != null) {
      final activeChat = matchedChat;
      final realHistory = TdlibService.instance.messagesOf(activeChat.id).value;
      final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : activeChat.messages;

      final chatDossier = ContactDossierStore.instance.getDossier(activeChat.id).value;
      final limit = session.messageLimit > 0
          ? session.messageLimit
          : (chatDossier.analysisMessageLimit > 0
              ? chatDossier.analysisMessageLimit
              : settings.contextMessageCount);
      final msgsToAnalyze = msgs.take(limit).toList();

      final hasRag = (session.ragFactSummary?.isNotEmpty == true) ||
          (chatDossier.ragFactSummary?.isNotEmpty == true);
      final ragSummary = session.ragFactSummary?.isNotEmpty == true
          ? session.ragFactSummary!
          : (chatDossier.ragFactSummary ?? '');
      final ragCount = session.ragFactSummaryCount > 0
          ? session.ragFactSummaryCount
          : (chatDossier.ragFactSummaryCount > 0 ? chatDossier.ragFactSummaryCount : msgsToAnalyze.length);

      final systemDirectives = StringBuffer();
      systemDirectives.writeln('Ты — проницательный, откровенный и независимый AI-копилот и аналитик переговоров.');
      systemDirectives.writeln('Ты помогаешь пользователю анализировать переписку в Telegram и вести диалоги.');
      systemDirectives.writeln('');
      systemDirectives.writeln('ГЛАВНЫЕ ПРИНЦИПЫ:');
      systemDirectives.writeln('1. Будь предельно честен, прямолинеен и объективен. Не пытайся сглаживать углы, придумывать лесть или использовать пустые корпоративные штампы.');
      systemDirectives.writeln('2. Если пользователь спрашивает твое мнение, оценку человека, мотивы, манипуляции, токсичность или "мудак ли он" — дай бескомпромиссную, психологически точную и доказательную оценку на основе реальных фактов и реплик.');
      systemDirectives.writeln('3. Если собеседник некомпетентен, ведет себя неадекватно, перекладывает работу, юлит или манипулирует — укажи на конкретные сигналы и предложи четкую линию защиты.');
      systemDirectives.writeln('4. Если пользователь просит предложить ответ — напиши уверенный, выверенный ответ, пресекающий манипуляции.');
      if (effectivePrompt.isNotEmpty) {
        systemDirectives.writeln('\nДОПОЛНИТЕЛЬНЫЕ ДИРЕКТИВЫ ПОЛЬЗОВАТЕЛЯ:\n$effectivePrompt');
      }

      if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
        systemDirectives.writeln('\n<dialogue_memory_summary>');
        systemDirectives.writeln(session.contextSummary!);
        systemDirectives.writeln('</dialogue_memory_summary>');
      }

      systemDirectives.writeln('');
      systemDirectives.writeln('<target_contact>');
      systemDirectives.writeln('Имя контакта: "${activeChat.title}"');
      if (activeChat.headerSubtitle.isNotEmpty) {
        systemDirectives.writeln('Статус/роль: "${activeChat.headerSubtitle}"');
      }
      if (chatDossier.goal.isNotEmpty) {
        systemDirectives.writeln('Цель пользователя: "${chatDossier.goal}"');
      }
      if (chatDossier.psychotype.isNotEmpty) {
        systemDirectives.writeln('Психотип контакта: "${chatDossier.psychotype}"');
      }
      if (chatDossier.tone.isNotEmpty) {
        systemDirectives.writeln('Рекомендуемый тон: "${chatDossier.tone}"');
      }
      if (chatDossier.facts.isNotEmpty) {
        systemDirectives.writeln('Факты: ${chatDossier.facts.join("; ")}');
      }
      if (chatDossier.summary.isNotEmpty) {
        systemDirectives.writeln('Саммари: "${chatDossier.summary}"');
      }
      systemDirectives.writeln('</target_contact>');
      systemDirectives.writeln('');

      if (hasRag && ragSummary.isNotEmpty) {
        // 10 recent raw messages for live conversational context
        final recentRaw = msgs.take(10).toList();
        final recentFormatted = <String>[];
        final ragLiveAllowed = <dynamic>{};
        for (final m in recentRaw) {
          if (ImageDescriptionService.isImageMessage(m)) {
            final hasCache = (m.id != 0 && ImageDescriptionService.instance.hasDescription(m.id)) ||
                ImageDescriptionService.instance.hasDescription(m.mediaPath) ||
                ImageDescriptionService.instance.hasDescription(m.thumbnailPath);
            if (!hasCache) {
              final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
              if (key.toString().isNotEmpty) {
                ragLiveAllowed.add(key);
                if (ragLiveAllowed.length >= 2) break;
              }
            }
          }
        }
        for (final m in recentRaw.reversed) {
          final sender = m.outgoing
              ? (isRu ? 'Вы' : 'You')
              : (m.senderName.isNotEmpty ? m.senderName : activeChat.title);
          String content = m.text.replaceAll('\n', ' ').trim();
          if (m.kind == MessageKind.voice) {
            final trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
                VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
            if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
              content = isRu ? '[🎤 Расшифровка: "$trans"]' : '[🎤 Voice: "$trans"]';
            } else {
              content = isRu ? '[🎤 Голосовое (${m.duration} сек)]' : '[🎤 Voice note (${m.duration}s)]';
            }
          } else if (ImageDescriptionService.isImageMessage(m)) {
            final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
            final allowLive = ragLiveAllowed.contains(key);
            String? desc = await ImageDescriptionService.instance.resolveImageDescriptionForContext(
              message: m,
              allowLiveVision: allowLive,
            );
            if (desc != null && desc.isNotEmpty) {
              content = isRu
                  ? '[🖼 Фото: $desc${content.isNotEmpty ? " (подпись: $content)" : ""}]'
                  : '[🖼 Photo: $desc${content.isNotEmpty ? " (caption: $content)" : ""}]';
            } else {
              final nameHint = m.fileName.isNotEmpty ? ': ${m.fileName}' : (content.isNotEmpty ? ': $content' : '');
              content = isRu ? '[🖼 Фото$nameHint]' : '[🖼 Photo$nameHint]';
            }
          } else if (m.kind == MessageKind.document) {
            content = isRu ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]' : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
          }
          recentFormatted.add('$sender: $content');
        }

        systemDirectives.writeln('<rag_chat_facts messages_analyzed="$ragCount" chat="${activeChat.title}">');
        systemDirectives.writeln(ragSummary);
        systemDirectives.writeln('</rag_chat_facts>');
        systemDirectives.writeln('');
        systemDirectives.writeln('<telegram_recent_raw_messages count="${recentRaw.length}">');
        systemDirectives.writeln(recentFormatted.join('\n'));
        systemDirectives.writeln('</telegram_recent_raw_messages>');

        tool = 'llm.analyzeRAG(chat: "${activeChat.title}", ragCount: $ragCount, recent: ${recentRaw.length}, model: "${settings.model}")';
        output = isRu
            ? 'Использована RAG-выжимка из $ragCount сообщ. + ${recentRaw.length} свежих реплик («${activeChat.title}»)'
            : 'Used RAG summary of $ragCount msgs + ${recentRaw.length} recent replies ("${activeChat.title}")';
      } else {
        // Форматируем сообщения с включением транскрибированных голосовых заметок и описаний фото
        // Ограничиваем живой Vision-анализ максимум 3 самыми свежими некэшированными фото
        final liveVisionAllowed = <dynamic>{};
        for (final m in msgsToAnalyze) {
          if (ImageDescriptionService.isImageMessage(m)) {
            final hasCache = (m.id != 0 && ImageDescriptionService.instance.hasDescription(m.id)) ||
                ImageDescriptionService.instance.hasDescription(m.mediaPath) ||
                ImageDescriptionService.instance.hasDescription(m.thumbnailPath);
            if (!hasCache) {
              final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
              if (key.toString().isNotEmpty) {
                liveVisionAllowed.add(key);
                if (liveVisionAllowed.length >= 3) break;
              }
            }
          }
        }

        final formattedList = <String>[];
        for (final m in msgsToAnalyze.reversed) {
          final sender = m.outgoing
              ? (isRu ? 'Вы' : 'You')
              : (m.senderName.isNotEmpty ? m.senderName : activeChat.title);
          String content = m.text.replaceAll('\n', ' ').trim();
          if (m.kind == MessageKind.voice) {
            String? trans = VoiceTranscriptionService.instance.getCachedTranscription(m.id) ??
                VoiceTranscriptionService.instance.getCachedTranscription(m.mediaPath);
            if (trans == null || trans.isEmpty) {
              if (m.mediaPath.isNotEmpty && File(m.mediaPath).existsSync()) {
                try {
                  trans = await VoiceTranscriptionService.instance.transcribeVoiceFile(
                    filePath: m.mediaPath,
                    messageId: m.id,
                    durationSeconds: m.duration,
                  );
                } catch (_) {}
              }
            }
            if (trans != null && trans.isNotEmpty && !trans.startsWith('[')) {
              content = isRu ? '[🎤 Расшифровка голосового: "$trans"]' : '[🎤 Voice transcript: "$trans"]';
            } else {
              content = isRu ? '[🎤 Голосовое сообщение (${m.duration} сек)]' : '[🎤 Voice note (${m.duration}s)]';
            }
          } else if (ImageDescriptionService.isImageMessage(m)) {
            final key = m.id != 0 ? m.id : (m.mediaPath.isNotEmpty ? m.mediaPath : m.thumbnailPath);
            final allowLive = liveVisionAllowed.contains(key);
            String? desc = await ImageDescriptionService.instance.resolveImageDescriptionForContext(
              message: m,
              allowLiveVision: allowLive,
            );
            if (desc != null && desc.isNotEmpty) {
              content = isRu
                  ? '[🖼 Фото: $desc${content.isNotEmpty ? " (подпись: $content)" : ""}]'
                  : '[🖼 Photo: $desc${content.isNotEmpty ? " (caption: $content)" : ""}]';
            } else {
              final nameHint = m.fileName.isNotEmpty ? ': ${m.fileName}' : (content.isNotEmpty ? ': $content' : '');
              content = isRu ? '[🖼 Фото$nameHint]' : '[🖼 Photo$nameHint]';
            }
          } else if (m.kind == MessageKind.video) {
            content = isRu ? '[🎬 Видео (${m.duration} сек)${content.isNotEmpty ? ": $content" : ""}]' : '[🎬 Video (${m.duration}s)${content.isNotEmpty ? ": $content" : ""}]';
          } else if (m.kind == MessageKind.document) {
            content = isRu ? '[📎 Документ: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]' : '[📎 Document: ${m.fileName} (${m.fileSize})${content.isNotEmpty ? ": $content" : ""}]';
          }
          formattedList.add('$sender: $content');
        }
        final transcript = formattedList.join('\n');

        systemDirectives.writeln('<telegram_chat_history chat="${activeChat.title}" messages_count="${msgsToAnalyze.length}">');
        systemDirectives.writeln(transcript);
        systemDirectives.writeln('</telegram_chat_history>');

        tool = 'llm.analyzeChat(chat: "${activeChat.title}", limit: ${msgsToAnalyze.length}, model: "${settings.model}")';
        output = isRu
            ? 'Проанализировано ${msgsToAnalyze.length} сообщений из чата «${activeChat.title}»'
            : 'Analyzed ${msgsToAnalyze.length} messages from "${activeChat.title}"';
      }

      reply = await AiModelService.instance.generateChatCompletion(
        prompt: effectiveQuery,
        systemPrompt: systemDirectives.toString(),
        history: conversationHistory,
        settings: settings,
        imagePath: (attachedPath != null && isImg) ? attachedPath : null,
      );
    } else {
      tool = 'llm.chat(model: "${settings.model}")';
      output = isRu ? 'Обработка запроса нейросетью ${settings.model}' : 'Processing via ${settings.model}';

      final systemDirectives = StringBuffer();
      systemDirectives.writeln('Ты — интеллектуальный персональный ассистент и советник.');
      systemDirectives.writeln('Роль агента: ${session.agentRole}.');
      if (effectivePrompt.isNotEmpty) {
        systemDirectives.writeln('Директивы: $effectivePrompt');
      }

      if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
        systemDirectives.writeln('\n<dialogue_memory_summary>');
        systemDirectives.writeln(session.contextSummary!);
        systemDirectives.writeln('</dialogue_memory_summary>');
      }

      reply = await AiModelService.instance.generateChatCompletion(
        prompt: effectiveQuery,
        systemPrompt: systemDirectives.toString(),
        history: conversationHistory,
        settings: settings,
        imagePath: (attachedPath != null && isImg) ? attachedPath : null,
      );
    }

    final agentMsg = CopilotMessage(
      text: reply,
      isUser: false,
      toolName: tool,
      toolOutput: output,
    );

    CopilotSessionStore.instance.addMessage(session.id, agentMsg);

    // Проверка автокомпрессии после ответа
    CopilotSessionStore.instance.checkAndAutoCompress(session.id, settings);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showPromptEditor(CopilotSession session) {
    final controller = TextEditingController(text: session.systemPrompt);
    final isContact = session.id.startsWith('contact_');
    final chatId = isContact ? session.id.replaceFirst('contact_', '') : null;
    final dossier = chatId != null ? ContactDossierStore.instance.getDossier(chatId).value : null;

    int messageLimit = session.messageLimit > 0
        ? session.messageLimit
        : (dossier != null && dossier.analysisMessageLimit > 0 ? dossier.analysisMessageLimit : 30);

    final ragPromptController = TextEditingController(
      text: session.ragPrompt.isNotEmpty
          ? session.ragPrompt
          : (dossier?.ragPrompt ?? CopilotSession.defaultRagPrompt),
    );

    final dialogueCompressionController = TextEditingController(
      text: session.dialogueCompressionPrompt.isNotEmpty
          ? session.dialogueCompressionPrompt
          : CopilotSession.defaultDialogueCompressionPrompt,
    );

    bool autoCompressEnabled = session.autoCompressEnabled;
    int autoCompressThreshold = session.autoCompressThreshold;
    int keepRawCount = session.keepRawCount;

    String? currentRagSummary = session.ragFactSummary ?? dossier?.ragFactSummary;
    int currentRagCount = session.ragFactSummaryCount > 0
        ? session.ragFactSummaryCount
        : (dossier?.ragFactSummaryCount ?? 0);
    DateTime? currentRagDate = session.ragFactUpdatedAt ?? dossier?.ragFactUpdatedAt;

    bool isExtractingRag = false;
    bool isCompressingDialogue = false;

    final isRu = I18n.instance.isRu;

    // Поиск целевого чата для RAG-экстракции
    final currentAcc = AccountManager.instance.currentAccount.value;
    final allChats = [
      ...TdlibService.instance.chats.value,
      ...AccountManager.instance.getChats(currentAcc.id),
    ];
    TgChat? targetChat;
    if (chatId != null) {
      final found = allChats.where((c) => c.id == chatId).toList();
      if (found.isNotEmpty) targetChat = found.first;
    }
    if (targetChat == null) {
      final activeId = AppState.selectedChatId.value;
      final found = allChats.where((c) => c.id == activeId).toList();
      if (found.isNotEmpty) targetChat = found.first;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Tg.sidebar,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              title: Row(
                children: [
                  Icon(session.avatarIcon, color: session.avatarColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('agent_directives_title', {'role': session.agentRole}),
                      style: const TextStyle(color: Tg.text, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- СЕКЦИЯ 1: ДИРЕКТИВЫ АГЕНТА ---
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: Tg.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isRu ? 'Директивы и системный промпт' : 'Agent Directives & Prompt',
                            style: const TextStyle(color: Tg.text, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('system_prompt_desc'),
                        style: const TextStyle(color: Tg.textDim, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: controller,
                          maxLines: 3,
                          style: const TextStyle(color: Tg.text, fontSize: 12.5),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: tr('agent_directives_hint'),
                            hintStyle: const TextStyle(color: Tg.textFaint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- СЕКЦИЯ 2: RAG-ВЫЖИМКА ФАКТОВ ИЗ ПЕРЕПИСКИ ---
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Tg.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.hub_outlined, color: Color(0xFF51B2FF), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isRu ? 'RAG-сбор сухих фактов из чата' : 'Chat RAG & Fact Extraction',
                                    style: const TextStyle(fontSize: 13, color: Tg.text, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (targetChat != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      targetChat.title,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF51B2FF), fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isRu
                                  ? 'Сжимает историю переписки Telegram в выжимку фактов по заданной призме. Копилот получит эту выжимку + 10 свежих реплик.'
                                  : 'Compresses chat history into dry facts per custom lens. Copilot receives this summary + 10 recent messages.',
                              style: const TextStyle(fontSize: 11, color: Tg.textDim, height: 1.3),
                            ),
                            const SizedBox(height: 12),

                            // Слайдер глубины RAG
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isRu ? 'Глубина сбора фактов (RAG):' : 'Fact extraction depth (RAG):',
                                  style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF51B2FF).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isRu ? '$messageLimit сообщ.' : '$messageLimit msgs',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF51B2FF)),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: messageLimit.toDouble().clamp(10.0, 500.0),
                                min: 10,
                                max: 500,
                                divisions: 49,
                                activeColor: const Color(0xFF51B2FF),
                                inactiveColor: Colors.white.withValues(alpha: 0.1),
                                onChanged: (val) {
                                  setDialogState(() => messageLimit = val.round());
                                },
                              ),
                            ),

                            // Призма RAG (промпт)
                            const SizedBox(height: 4),
                            Text(
                              isRu ? 'Призма взгляда для RAG (какие факты извлекать):' : 'RAG filter lens (what facts to gather):',
                              style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Tg.sidebar,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: TextField(
                                controller: ragPromptController,
                                maxLines: 2,
                                style: const TextStyle(color: Tg.text, fontSize: 12),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: isRu ? 'Укажите фокус: договоренности, условия, спорные реплики...' : 'Extraction focus...',
                                  hintStyle: const TextStyle(color: Tg.textFaint),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Кнопка экстракции RAG и статус
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF51B2FF).withValues(alpha: 0.2),
                                    foregroundColor: const Color(0xFF51B2FF),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: const Color(0xFF51B2FF).withValues(alpha: 0.4)),
                                    ),
                                  ),
                                  icon: isExtractingRag
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF51B2FF)))
                                      : const Icon(Icons.bolt_rounded, size: 16),
                                  label: Text(
                                    isExtractingRag
                                        ? (isRu ? 'Сбор фактов...' : 'Extracting...')
                                        : (isRu ? 'Собрать RAG-выжимку ($messageLimit сообщ.)' : 'Extract RAG Facts ($messageLimit msgs)'),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: isExtractingRag || targetChat == null
                                      ? null
                                      : () async {
                                          final chat = targetChat;
                                          if (chat == null) return;
                                          setDialogState(() => isExtractingRag = true);
                                          try {
                                            final realHistory = TdlibService.instance.messagesOf(chat.id).value;
                                            final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : chat.messages;
                                            final summary = await CopilotSessionStore.instance.runRagFactExtraction(
                                              sessionId: session.id,
                                              chatId: chat.id,
                                              messages: msgs,
                                              limit: messageLimit,
                                              ragPrompt: ragPromptController.text,
                                              chatTitle: chat.title,
                                            );
                                            setDialogState(() {
                                              currentRagSummary = summary;
                                              currentRagCount = msgs.take(messageLimit).length;
                                              currentRagDate = DateTime.now();
                                            });
                                            if (context.mounted) {
                                              TgToast.show(context, isRu ? '⚡ RAG-выжимка из $currentRagCount сообщений собрана!' : '⚡ RAG summary extracted!');
                                            }
                                          } catch (e) {
                                            if (context.mounted) TgToast.show(context, 'Ошибка RAG: $e');
                                          } finally {
                                            setDialogState(() => isExtractingRag = false);
                                          }
                                        },
                                ),
                                const Spacer(),
                                if (currentRagSummary != null && currentRagSummary!.isNotEmpty)
                                  IconButton(
                                    tooltip: isRu ? 'Очистить RAG-выжимку' : 'Clear RAG summary',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Tg.textDim),
                                    onPressed: () {
                                      setDialogState(() {
                                        currentRagSummary = null;
                                        currentRagCount = 0;
                                        currentRagDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),

                            // Превью активного RAG-саммари
                            if (currentRagSummary != null && currentRagSummary!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C48C).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF00C48C)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            currentRagDate != null
                                                ? (isRu
                                                    ? 'RAG-выжимка активна (сжато $currentRagCount сообщ., в ${currentRagDate!.hour.toString().padLeft(2, "0")}:${currentRagDate!.minute.toString().padLeft(2, "0")})'
                                                    : 'Active RAG summary ($currentRagCount msgs, at ${currentRagDate!.hour.toString().padLeft(2, "0")}:${currentRagDate!.minute.toString().padLeft(2, "0")})')
                                                : (isRu ? 'RAG-выжимка активна (сжато $currentRagCount сообщ.)' : 'Active RAG summary ($currentRagCount msgs)'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentRagSummary!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Tg.textDim, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- СЕКЦИЯ 3: ПАМЯТЬ И АВТОКОМПРЕССИЯ ДИАЛОГА С КОПИЛОТОМ ---
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Tg.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.memory_rounded, color: Color(0xFF51B2FF), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isRu ? 'Память и автосжатие диалога с Copilot' : 'Copilot Dialogue Memory & Compression',
                                    style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRu
                                  ? 'Сжимает длинную историю нашего общения с Копилотом в память при достижении порога, сохраняя свежие реплики сырыми.'
                                  : 'Compresses long user-Copilot conversation history into memory upon reaching threshold, keeping recent turns raw.',
                              style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                            ),
                            const SizedBox(height: 8),

                            // Тумблер автокомпрессии
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isRu ? 'Автокомпрессия при переполнении:' : 'Auto-compress on threshold:',
                                  style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w400),
                                ),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch.adaptive(
                                    value: autoCompressEnabled,
                                    activeTrackColor: const Color(0xFF51B2FF).withValues(alpha: 0.35),
                                    activeThumbColor: const Color(0xFF51B2FF),
                                    onChanged: (val) {
                                      setDialogState(() => autoCompressEnabled = val);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (autoCompressEnabled) ...[
                              const SizedBox(height: 6),
                              // Слайдер порога срабатывания
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isRu ? 'Порог срабатывания сжатия:' : 'Compression trigger threshold:',
                                    style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isRu ? '$autoCompressThreshold сообщ.' : '$autoCompressThreshold msgs',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF51B2FF)),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: autoCompressThreshold.toDouble().clamp(10.0, 80.0),
                                  min: 10,
                                  max: 80,
                                  divisions: 14,
                                  activeColor: const Color(0xFF51B2FF),
                                  inactiveColor: Colors.white.withValues(alpha: 0.08),
                                  onChanged: (val) {
                                    setDialogState(() => autoCompressThreshold = val.round());
                                  },
                                ),
                              ),

                              // Слайдер окна свежих сырых сообщений
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isRu ? 'Свежих сообщений без сжатия (окно):' : 'Raw recent window:',
                                    style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isRu ? '$keepRawCount сообщ.' : '$keepRawCount msgs',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF51B2FF)),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: keepRawCount.toDouble().clamp(3.0, 20.0),
                                  min: 3,
                                  max: 20,
                                  divisions: 17,
                                  activeColor: const Color(0xFF51B2FF),
                                  inactiveColor: Colors.white.withValues(alpha: 0.08),
                                  onChanged: (val) {
                                    setDialogState(() => keepRawCount = val.round());
                                  },
                                ),
                              ),

                              // Призма сжатия диалога
                              const SizedBox(height: 3),
                              Text(
                                isRu ? 'Призма сжатия диалога с Copilot:' : 'Dialogue compression lens:',
                                style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Tg.sidebar,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: TextField(
                                  controller: dialogueCompressionController,
                                  maxLines: 2,
                                  style: const TextStyle(color: Tg.text, fontSize: 11.5),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: isRu ? 'Инструкция для сжатия диалога...' : 'Compression instructions...',
                                    hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            // Ручная кнопка сжатия диалога сейчас
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF51B2FF),
                                    side: BorderSide(color: const Color(0xFF51B2FF).withValues(alpha: 0.35)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: isCompressingDialogue
                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF51B2FF)))
                                      : const Icon(Icons.archive_outlined, size: 14),
                                  label: Text(
                                    isCompressingDialogue
                                        ? (isRu ? 'Сжатие...' : 'Compressing...')
                                        : (isRu ? 'Сжать диалог сейчас (${session.messages.length} сообщ.)' : 'Compress dialogue now (${session.messages.length} msgs)'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  onPressed: isCompressingDialogue
                                      ? null
                                      : () async {
                                          setDialogState(() => isCompressingDialogue = true);
                                          try {
                                            final compressed = await CopilotSessionStore.instance.compressSessionIntelligent(session.id);
                                            if (context.mounted) {
                                              if (compressed) {
                                                TgToast.show(context, isRu ? '🗜️ Диалог сжат и сохранен в памяти!' : '🗜️ Dialogue compressed to memory!');
                                              } else {
                                                TgToast.show(context, isRu ? 'В диалоге мало сообщений (меньше окна $keepRawCount)' : 'Dialogue has fewer messages than window ($keepRawCount)');
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) TgToast.show(context, 'Ошибка сжатия: $e');
                                          } finally {
                                            setDialogState(() => isCompressingDialogue = false);
                                          }
                                        },
                                ),
                                const Spacer(),
                                if (session.contextSummary != null && session.contextSummary!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF51B2FF).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isRu ? '${session.summaryTokenCount} ток. в памяти' : '${session.summaryTokenCount} tok. in memory',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF51B2FF), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: session.avatarColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final text = controller.text;
                    final ragPrompt = ragPromptController.text;
                    final dialoguePrompt = dialogueCompressionController.text;

                    CopilotSessionStore.instance.updateSessionPrompt(session.id, text);
                    CopilotSessionStore.instance.updateSessionMessageLimit(session.id, messageLimit);
                    CopilotSessionStore.instance.updateSessionRagConfig(
                      session.id,
                      prompt: ragPrompt,
                      summary: currentRagSummary,
                      count: currentRagCount,
                    );
                    CopilotSessionStore.instance.updateSessionCompressionConfig(
                      session.id,
                      enabled: autoCompressEnabled,
                      threshold: autoCompressThreshold,
                      keepRaw: keepRawCount,
                      prompt: dialoguePrompt,
                    );

                    if (chatId != null) {
                      ContactDossierStore.instance.updateSystemPrompt(chatId, text);
                      ContactDossierStore.instance.updateAnalysisMessageLimit(chatId, messageLimit);
                      ContactDossierStore.instance.updateRagPrompt(chatId, ragPrompt);
                      if (currentRagSummary != null) {
                        ContactDossierStore.instance.updateRagSummary(chatId, currentRagSummary!, currentRagCount);
                      }
                    }
                    Navigator.of(context).pop();
                    TgToast.show(context, tr('directives_updated_toast'));
                    if (mounted) setState(() {});
                  },
                  child: Text(tr('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSandwichInspector(CopilotSession session, AiSettings settings) {
    final sandwich = CopilotSessionStore.instance.buildSandwichPrompt(
      session,
      settings,
      _controller.text.isEmpty ? '[Текущий запрос]' : _controller.text,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Tg.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Tg.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.layers_outlined, color: Tg.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                tr('context_sandwich_title'),
                style: Tg.title,
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('sandwich_desc'),
                    style: const TextStyle(color: Tg.textDim, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),

                  // Слой 1: Верхний хлеб
                  _buildSandwichLayer(
                    layerNumber: '1',
                    layerName: tr('sandwich_layer_top_bread'),
                    tokens: sandwich['systemTokens'] as int,
                    color: const Color(0xFFFF9F43),
                    description: 'Персона агента, инструкции, формат вывода и подключенные инструменты.',
                    content: sandwich['systemSlice'] as String,
                  ),
                  const SizedBox(height: 10),

                  // Слой 2: Начинка - Сжатое саммари
                  _buildSandwichLayer(
                    layerNumber: '2',
                    layerName: tr('sandwich_layer_summary'),
                    tokens: sandwich['summaryTokens'] as int,
                    color: const Color(0xFF00C48C),
                    description: sandwich['summarySlice'] != null
                        ? tr('sandwich_layer_summary_compressed')
                        : tr('sandwich_layer_summary_compact'),
                    content: sandwich['summarySlice'] as String? ?? (I18n.instance.isRu ? '— Нет сжатого контекста —' : '— No compressed context —'),
                  ),
                  const SizedBox(height: 10),

                  // Слой 3: Начинка - Сырые недавние сообщения
                  _buildSandwichLayer(
                    layerNumber: '3',
                    layerName: tr('sandwich_layer_raw'),
                    tokens: sandwich['rawTokens'] as int,
                    color: const Color(0xFF51B2FF),
                    description: tr('sandwich_layer_raw_desc', {'count': session.rawMessagesCount.toString()}),
                    content: session.messages.map((m) => '${m.isUser ? tr("you") : tr("bot")}: ${m.text}').join('\n'),
                  ),
                  const SizedBox(height: 10),

                  // Слой 4: Нижний хлеб
                  _buildSandwichLayer(
                    layerNumber: '4',
                    layerName: tr('sandwich_layer_bottom_bread'),
                    tokens: sandwich['bottomTokens'] as int,
                    color: const Color(0xFFFF7675),
                    description: tr('sandwich_layer_bottom_desc'),
                    content: sandwich['bottomSlice'] as String,
                  ),
                  const SizedBox(height: 14),

                  // Итого
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Tg.field,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('total_request_volume'), style: const TextStyle(color: Tg.textDim, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              '${sandwich["totalTokens"]} tok / ${I18n.instance.isRu ? "Порог: " : "Threshold: "}${settings.compressionVolumeThreshold}',
                              style: const TextStyle(color: Tg.text, fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          ],
                        ),
                        if (session.messages.length > settings.compressionKeepRawCount)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C48C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              CopilotSessionStore.instance.compressSession(
                                session.id,
                                keepRawCount: settings.compressionKeepRawCount,
                              );
                              Navigator.of(context).pop();
                              TgToast.show(context, tr('context_compressed_toast'));
                            },
                            icon: const Icon(Icons.compress, size: 16),
                            label: Text(tr('compress_now')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Tg.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('close')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSandwichLayer({
    required String layerNumber,
    required String layerName,
    required int tokens,
    required Color color,
    required String description,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  layerName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tokens tok',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 11.5, color: Tg.textDim)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CopilotSessionStore.instance.activeSessionId,
      builder: (context, activeId, _) {
        return ValueListenableBuilder<List<CopilotSession>>(
          valueListenable: CopilotSessionStore.instance.sessions,
          builder: (context, sessions, _) {
            final session = sessions.firstWhere(
              (s) => s.id == activeId,
              orElse: () => sessions.first,
            );

            return ValueListenableBuilder<AiSettings>(
              valueListenable: AiSettingsStore.instance.settings,
              builder: (context, settings, _) {
                return Container(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      _buildHeader(session, settings),
                      _buildQuickActionCards(session),
                      if (session.contextSummary != null)
                        _buildSummaryBanner(session),
                      Expanded(child: _buildMessagesList(session)),
                      _buildInputBar(session),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(CopilotSession session, AiSettings settings) {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tg.border),
      ),
      child: Row(
        children: [
          if (widget.showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Tg.textDim),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              tooltip: tr('back'),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: session.avatarColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: session.avatarColor.withValues(alpha: 0.5)),
            ),
            child: Icon(session.avatarIcon, color: session.avatarColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Tg.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: session.avatarColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.agentRole,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: session.avatarColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${session.model ?? settings.model} • ${settings.provider}',
                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                ),
              ],
            ),
          ),

          // Кнопка инспектора бутерброда / объема токенов
          Tooltip(
            message: tr('context_inspector_tooltip'),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showSandwichInspector(session, settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: session.contextSummary != null
                      ? const Color(0xFF00C48C).withValues(alpha: 0.18)
                      : Tg.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: session.contextSummary != null
                        ? const Color(0xFF00C48C).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      session.contextSummary != null ? Icons.compress : Icons.layers_outlined,
                      size: 14,
                      color: session.contextSummary != null ? const Color(0xFF00C48C) : Tg.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${session.totalTokens} tok',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: Tg.fontMedium,
                        color: session.contextSummary != null ? const Color(0xFF00C48C) : Tg.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Кнопка директив / промпта агента
          Tooltip(
            message: tr('agent_directives_tooltip'),
            child: CircleIconButton(
              icon: Icons.tune_rounded,
              iconSize: 19,
              color: Tg.textDim,
              onTap: () => _showPromptEditor(session),
            ),
          ),

          // Кнопка очистки сообщений
          Tooltip(
            message: tr('clear_history_tooltip'),
            child: CircleIconButton(
              icon: Icons.delete_sweep_outlined,
              iconSize: 19,
              color: Tg.textDim,
              onTap: () {
                CopilotSessionStore.instance.clearSessionMessages(session.id);
                TgToast.show(context, tr('copilot_cleared_toast'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(CopilotSession session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00C48C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.compress, size: 16, color: Color(0xFF00C48C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🗜️ Контекст сжат: Сводка истории (${session.summaryTokenCount} токенов)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C48C),
                      ),
                    ),
                  ),
                  Icon(
                    _summaryExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF00C48C),
                  ),
                ],
              ),
            ),
          ),
          if (_summaryExpanded && session.contextSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                session.contextSummary!,
                style: const TextStyle(fontSize: 11.5, color: Tg.textDim, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(CopilotSession session) {
    List<String> actions;
    final role = session.agentRole.toLowerCase();
    final isRu = I18n.instance.isRu;

    if (session.id.startsWith('contact_')) {
      actions = [
        isRu ? '📊 Анализ человека и переписки' : '📊 Analyze person & chat',
        isRu ? '🧐 Манипулирует ли собеседник?' : '🧐 Is contact manipulating?',
        isRu ? '🎯 Истинные мотивы собеседника' : '🎯 Real contact motives',
        isRu ? '✍️ Предложи идеальный ответ' : '✍️ Suggest best reply',
        isRu ? '⏳ Зафиксировать договоренности' : '⏳ Lock agreements',
      ];
    } else if (role.contains('hunter') || role.contains('ваканси') || role.contains('лид')) {
      actions = [
        isRu ? '💼 Вакансии Flutter Remote' : '💼 Flutter Remote Jobs',
        isRu ? '🔍 Спарсить чат заказов' : '🔍 Parse Orders Chat',
        isRu ? '📋 Подготовить отклик' : '📋 Draft Proposal',
        isRu ? '🎯 Фильтр по рейту от \$4000' : '🎯 Rate Filter \$4000+',
      ];
    } else if (role.contains('crm') || role.contains('анали')) {
      actions = [
        isRu ? '📊 Саммари переписки' : '📊 Conversation Summary',
        isRu ? '🎯 Досье контакта' : '🎯 Contact Dossier',
        isRu ? '⏳ Зафиксировать договоренности' : '⏳ Lock Agreements',
        isRu ? '📝 Экспорт в CRM заметки' : '📝 Export to CRM Notes',
      ];
    } else if (role.contains('code') || role.contains('архитект')) {
      actions = [
        isRu ? '🛠️ Ревью Isolate C++ в TDLib' : '🛠️ Review C++ Isolate in TDLib',
        isRu ? '⚡ Анализ задержки звонков' : '⚡ Call Latency Analysis',
        isRu ? '🧪 Написать unit-тесты' : '🧪 Generate Unit Tests',
        isRu ? '📦 Проверить сжатие контекста' : '📦 Check Context Compression',
      ];
    } else {
      actions = [
        isRu ? '📊 Анализ активного диалога' : '📊 Analyze Active Chat',
        isRu ? '🧐 Мотивы и скрытые цели' : '🧐 Motives & Hidden Goals',
        isRu ? '💼 Найти вакансии Flutter' : '💼 Find Flutter Jobs',
        isRu ? '✍️ Предложи ответ в чат' : '✍️ Draft Chat Reply',
      ];
    }

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final action = actions[i];
          return ActionChip(
            label: Text(action),
            backgroundColor: Tg.sidebar.withValues(alpha: 0.9),
            labelStyle: const TextStyle(
              fontSize: 12,
              color: Tg.text,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () => _sendMessage(session, action),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList(CopilotSession session) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: session.messages.length,
      itemBuilder: (context, index) {
        final msg = session.messages[index];
        return _buildMessageBubble(session, msg);
      },
    );
  }

  Widget _buildMessageBubble(CopilotSession session, CopilotMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF2B5278) : const Color(0xFF182533),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: msg.isUser
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(session.avatarIcon, size: 13, color: session.avatarColor),
                  const SizedBox(width: 6),
                  Text(
                    session.agentRole,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: session.avatarColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (msg.toolName != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF51B2FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 13, color: Color(0xFF51B2FF)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            msg.toolName!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF51B2FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (msg.toolOutput != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        msg.toolOutput!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Tg.textDim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (msg.attachmentPath != null) ...[
              if (msg.isImageAttachment && File(msg.attachmentPath!).existsSync())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
                      child: Image.file(
                        File(msg.attachmentPath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file_rounded, size: 16, color: Color(0xFF51B2FF)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          msg.attachmentName ?? 'Файл',
                          style: const TextStyle(fontSize: 12, color: Tg.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            SelectableText.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.35),
                children: LinkHandler.buildSpans(
                  context: context,
                  text: msg.text,
                  outgoing: msg.isUser,
                  linkColor: msg.isUser ? const Color(0xFFE0D8FF) : const Color(0xFF51B2FF),
                  baseStyle: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.35),
                ),
              ),
              cursorColor: Tg.accent,
              selectionColor: Tg.accent.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingBar(CopilotSession session) {
    final isRu = I18n.instance.isRu;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Tg.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_recordSeconds),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Tg.text,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isRu ? 'Говорите, идёт распознавание...' : 'Recording voice for Copilot...',
              style: const TextStyle(fontSize: 13, color: Tg.textDim),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textFaint),
            onPressed: () => _stopVoice(send: false, session: session),
            tooltip: tr('cancel'),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _stopVoice(send: true, session: session),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: session.avatarColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(CopilotSession session) {
    if (_isRecordingVoice) {
      return _buildVoiceRecordingBar(session);
    }

    final isTextEmpty = _controller.text.trim().isEmpty && _attachedFilePath == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachedFilePath != null)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF51B2FF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (_isAttachedImage && File(_attachedFilePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(_attachedFilePath!),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.attach_file_rounded, size: 20, color: Color(0xFF51B2FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _attachedFileName ?? 'Файл',
                    style: const TextStyle(fontSize: 12.5, color: Tg.text, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _attachedFilePath = null;
                    _attachedFileName = null;
                    _isAttachedImage = false;
                  }),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 16, color: Tg.textFaint),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Tg.sidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file_rounded, size: 20, color: Tg.textDim),
                onPressed: _pickAttachment,
                tooltip: I18n.instance.isRu ? 'Прикрепить файл или фото' : 'Attach file or photo',
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (val) => _sendMessage(session, val),
                  style: const TextStyle(fontSize: 14, color: Tg.text),
                  decoration: InputDecoration(
                    hintText: tr('ask_agent_placeholder', {'role': session.agentRole}),
                    hintStyle: const TextStyle(fontSize: 13.5, color: Tg.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isTextEmpty)
                Tooltip(
                  message: I18n.instance.isRu ? 'Надиктовать голосом' : 'Voice dictation',
                  child: GestureDetector(
                    onTap: _startVoice,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Tg.field,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(Icons.mic_none_rounded, size: 20, color: session.avatarColor),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _sendMessage(session, _controller.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: session.avatarColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
