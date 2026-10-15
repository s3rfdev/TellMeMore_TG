import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../ai_copilot/models/contact_dossier.dart';
import '../../ai_copilot/models/copilot_session.dart';
import '../../ai_copilot/services/copilot_session_store.dart';

/// Диалог настройки системного промпта, RAG-сжатия и контекстной памяти AI для конкретного чата.
class ChatSystemPromptDialog extends StatefulWidget {
  const ChatSystemPromptDialog({super.key, required this.chat});

  final TgChat chat;

  static Future<void> show(BuildContext context, TgChat chat) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => ChatSystemPromptDialog(chat: chat),
    );
  }

  @override
  State<ChatSystemPromptDialog> createState() => _ChatSystemPromptDialogState();
}

class _ChatSystemPromptDialogState extends State<ChatSystemPromptDialog> {
  late final TextEditingController _promptController;
  late final TextEditingController _goalController;
  late final TextEditingController _toneController;
  late final TextEditingController _ragPromptController;
  late final TextEditingController _dialogueCompressionController;

  int _messageLimit = 30;
  bool _autoCompressEnabled = true;
  int _autoCompressThreshold = 20;
  int _keepRawCount = 6;

  bool _isExtractingRag = false;
  bool _isCompressingDialogue = false;

  String? _currentRagSummary;
  int _currentRagCount = 0;
  DateTime? _currentRagDate;

  @override
  void initState() {
    super.initState();
    final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
    final sessionId = 'contact_${widget.chat.id}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    _promptController = TextEditingController(text: dossier.systemPrompt);
    _goalController = TextEditingController(text: dossier.goal);
    _toneController = TextEditingController(text: dossier.tone);
    _messageLimit = dossier.analysisMessageLimit > 0 ? dossier.analysisMessageLimit : 30;

    _ragPromptController = TextEditingController(
      text: dossier.ragPrompt.isNotEmpty ? dossier.ragPrompt : ContactDossier.defaultRagPrompt,
    );
    _dialogueCompressionController = TextEditingController(
      text: dossier.dialogueCompressionPrompt.isNotEmpty
          ? dossier.dialogueCompressionPrompt
          : (existingSession?.dialogueCompressionPrompt.isNotEmpty == true
              ? existingSession!.dialogueCompressionPrompt
              : CopilotSession.defaultDialogueCompressionPrompt),
    );

    _autoCompressEnabled = dossier.autoCompressEnabled;
    _autoCompressThreshold = dossier.autoCompressThreshold;
    _keepRawCount = dossier.keepRawCount;

    _currentRagSummary = dossier.ragFactSummary ?? existingSession?.ragFactSummary;
    _currentRagCount = dossier.ragFactSummaryCount > 0
        ? dossier.ragFactSummaryCount
        : (existingSession?.ragFactSummaryCount ?? 0);
    _currentRagDate = dossier.ragFactUpdatedAt ?? existingSession?.ragFactUpdatedAt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _goalController.dispose();
    _toneController.dispose();
    _ragPromptController.dispose();
    _dialogueCompressionController.dispose();
    super.dispose();
  }

  void _save() {
    final store = ContactDossierStore.instance;
    final prompt = _promptController.text.trim();
    final goal = _goalController.text.trim();
    final tone = _toneController.text.trim();
    final ragPrompt = _ragPromptController.text.trim();
    final dialoguePrompt = _dialogueCompressionController.text.trim();

    store.updateSystemPrompt(widget.chat.id, prompt);
    store.updateGoal(widget.chat.id, goal);
    store.updateTone(widget.chat.id, tone);
    store.updateAnalysisMessageLimit(widget.chat.id, _messageLimit);
    store.updateRagPrompt(widget.chat.id, ragPrompt);
    if (_currentRagSummary != null) {
      store.updateRagSummary(widget.chat.id, _currentRagSummary!, _currentRagCount);
    }
    store.updateCompressionConfig(
      widget.chat.id,
      enabled: _autoCompressEnabled,
      threshold: _autoCompressThreshold,
      keepRaw: _keepRawCount,
      prompt: dialoguePrompt,
    );

    // Синхронизируем настройки с соответствующей сессией Copilot, если она существует
    final sessionId = 'contact_${widget.chat.id}';
    CopilotSessionStore.instance.updateSessionPrompt(sessionId, prompt);
    CopilotSessionStore.instance.updateSessionRagConfig(
      sessionId,
      prompt: ragPrompt,
      summary: _currentRagSummary,
      count: _currentRagCount,
    );
    CopilotSessionStore.instance.updateSessionCompressionConfig(
      sessionId,
      enabled: _autoCompressEnabled,
      threshold: _autoCompressThreshold,
      keepRaw: _keepRawCount,
      prompt: dialoguePrompt,
    );

    final isRu = I18n.instance.isRu;
    TgToast.show(
      context,
      isRu ? '✓ Настройки контекста и RAG сохранены' : '✓ Context & RAG settings saved',
      icon: Icons.check_circle_rounded,
    );

    Navigator.of(context).pop();
  }

  void _openInCopilot() {
    _save();
    final sessionId = 'contact_${widget.chat.id}';
    final existing = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    final isRu = I18n.instance.isRu;
    final prompt = _promptController.text.trim();
    final ragPrompt = _ragPromptController.text.trim();
    final dialoguePrompt = _dialogueCompressionController.text.trim();

    if (existing == null) {
      final newSession = CopilotSession(
        id: sessionId,
        title: '👤 ${widget.chat.title}',
        agentRole: isRu ? 'Ассистент по ${widget.chat.title}' : 'Assistant for ${widget.chat.title}',
        systemPrompt: prompt,
        ragPrompt: ragPrompt,
        ragFactSummary: _currentRagSummary,
        ragFactSummaryCount: _currentRagCount,
        ragFactUpdatedAt: _currentRagDate,
        autoCompressEnabled: _autoCompressEnabled,
        autoCompressThreshold: _autoCompressThreshold,
        keepRawCount: _keepRawCount,
        dialogueCompressionPrompt: dialoguePrompt,
        avatarIcon: Icons.person_pin_rounded,
        avatarColor: Tg.accent,
        messages: [
          CopilotMessage(
            text: isRu
                ? 'Чат с агентом по контакту **${widget.chat.title}** создан.\n'
                    '${prompt.isNotEmpty ? "Установлены директивы:\n*$prompt*\n\n" : ""}'
                    'Напишите мне задачу: составить ответ, изучить переписку или проанализировать позицию собеседника.'
                : 'Agent chat for **${widget.chat.title}** created.\n'
                    '${prompt.isNotEmpty ? "Configured directives:\n*$prompt*\n\n" : ""}'
                    'Tell me your task: draft a response, study chat history, or analyze contact stances.',
            isUser: false,
          ),
        ],
      );
      final updated = List<CopilotSession>.from(CopilotSessionStore.instance.sessions.value)..insert(0, newSession);
      CopilotSessionStore.instance.sessions.value = updated;
      CopilotSessionStore.instance.activeSessionId.value = sessionId;
    } else {
      CopilotSessionStore.instance.updateSessionPrompt(sessionId, prompt);
      CopilotSessionStore.instance.updateSessionRagConfig(
        sessionId,
        prompt: ragPrompt,
        summary: _currentRagSummary,
        count: _currentRagCount,
      );
      CopilotSessionStore.instance.updateSessionCompressionConfig(
        sessionId,
        enabled: _autoCompressEnabled,
        threshold: _autoCompressThreshold,
        keepRaw: _keepRawCount,
        prompt: dialoguePrompt,
      );
      CopilotSessionStore.instance.selectSession(sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = I18n.instance.isRu;
    final sessionId = 'contact_${widget.chat.id}';
    final existingSession = CopilotSessionStore.instance.sessions.value
        .where((s) => s.id == sessionId)
        .firstOrNull;

    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок диалога
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFF51B2FF).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF51B2FF), size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Системный промпт AI' : 'AI System Prompt',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tg.text),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isRu
                            ? 'Директивы, RAG и управление памятью для «${widget.chat.title}»'
                            : 'Directives, RAG & memory controls for "${widget.chat.title}"',
                        style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Tg.textDim, size: 19),
                  splashRadius: 18,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Контент формы с прокруткой
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Поле системного промпта
                    Text(
                      isRu ? 'Системные инструкции (Директивы агента)' : 'System Instructions (Agent Directives)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _promptController,
                      maxLines: 4,
                      minLines: 2,
                      style: const TextStyle(fontSize: 12.5, color: Tg.text, height: 1.35),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Tg.field,
                        hintText: isRu
                            ? 'Например: Отвечай коротко и вежливо. Главная задача — выяснить дедлайн проекта и предложить встречу в понедельник.'
                            : 'E.g.: Reply concisely and professionally. Primary goal is to clarify project deadline and propose a call on Monday.',
                        hintStyle: const TextStyle(color: Tg.textDim, fontSize: 12),
                        contentPadding: const EdgeInsets.all(11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: Color(0xFF51B2FF), width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Двухколоночный ряд: Цель и Тон общения
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRu ? 'Цель общения' : 'Communication Goal',
                                style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _goalController,
                                style: const TextStyle(fontSize: 12, color: Tg.text),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Tg.field,
                                  isDense: true,
                                  hintText: isRu ? 'Договориться о встрече' : 'Schedule a meeting',
                                  hintStyle: const TextStyle(color: Tg.textDim, fontSize: 11.5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF51B2FF), width: 1.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRu ? 'Тон и стиль общения' : 'Tone & Voice Style',
                                style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _toneController,
                                style: const TextStyle(fontSize: 12, color: Tg.text),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Tg.field,
                                  isDense: true,
                                  hintText: isRu ? 'Деловой / Дружелюбный' : 'Business / Friendly',
                                  hintStyle: const TextStyle(color: Tg.textDim, fontSize: 11.5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF51B2FF), width: 1.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // КАРТОЧКА 1: RAG-сбор сухих фактов из истории переписки
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              const Icon(Icons.hub_outlined, color: Color(0xFF51B2FF), size: 16),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  isRu ? 'RAG-сбор сухих фактов из чата' : 'Chat RAG & Fact Extraction',
                                  style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  widget.chat.title,
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF51B2FF), fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRu
                                ? 'Сжимает историю переписки Telegram в выжимку фактов по заданной призме. Агент получит эту выжимку фактов + свежие реплики.'
                                : 'Compresses chat history into dry facts per custom lens. Agent receives this summary + recent messages.',
                            style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                          ),
                          const SizedBox(height: 10),

                          // Слайдер глубины RAG
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isRu ? 'Глубина сбора фактов (RAG):' : 'Fact extraction depth (RAG):',
                                style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w500),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF51B2FF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  isRu ? '$_messageLimit сообщ.' : '$_messageLimit msgs',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF51B2FF)),
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
                              value: _messageLimit.toDouble().clamp(10.0, 500.0),
                              min: 10,
                              max: 500,
                              divisions: 49,
                              activeColor: const Color(0xFF51B2FF),
                              inactiveColor: Colors.white.withValues(alpha: 0.08),
                              onChanged: (val) {
                                setState(() => _messageLimit = val.round());
                              },
                            ),
                          ),

                          // Призма RAG (промпт)
                          const SizedBox(height: 2),
                          Text(
                            isRu ? 'Призма взгляда для RAG (какие факты извлекать):' : 'RAG filter lens (what facts to gather):',
                            style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Tg.sidebar,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: _ragPromptController,
                              maxLines: 2,
                              style: const TextStyle(color: Tg.text, fontSize: 11.5),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: isRu ? 'Укажите фокус: договоренности, условия, спорные реплики...' : 'Extraction focus...',
                                hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Кнопка экстракции RAG и статус
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF51B2FF).withValues(alpha: 0.18),
                                  foregroundColor: const Color(0xFF51B2FF),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                    side: BorderSide(color: const Color(0xFF51B2FF).withValues(alpha: 0.35)),
                                  ),
                                ),
                                icon: _isExtractingRag
                                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF51B2FF)))
                                    : const Icon(Icons.bolt_rounded, size: 15),
                                label: Text(
                                  _isExtractingRag
                                      ? (isRu ? 'Сбор фактов...' : 'Extracting...')
                                      : (isRu ? 'Собрать RAG-выжимку ($_messageLimit сообщ.)' : 'Extract RAG Facts ($_messageLimit msgs)'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                onPressed: _isExtractingRag
                                    ? null
                                    : () async {
                                        setState(() => _isExtractingRag = true);
                                        try {
                                          final realHistory = TdlibService.instance.messagesOf(widget.chat.id).value;
                                          final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : widget.chat.messages;
                                          final sessionId = 'contact_${widget.chat.id}';
                                          final summary = await CopilotSessionStore.instance.runRagFactExtraction(
                                            sessionId: sessionId,
                                            chatId: widget.chat.id,
                                            messages: msgs,
                                            limit: _messageLimit,
                                            ragPrompt: _ragPromptController.text,
                                            chatTitle: widget.chat.title,
                                          );
                                          setState(() {
                                            _currentRagSummary = summary;
                                            _currentRagCount = msgs.length > _messageLimit ? _messageLimit : msgs.length;
                                            _currentRagDate = DateTime.now();
                                          });
                                          if (context.mounted) {
                                            TgToast.show(
                                              context,
                                              isRu
                                                  ? '⚡ RAG-выжимка из $_currentRagCount сообщений собрана!'
                                                  : '⚡ RAG summary extracted!',
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) TgToast.show(context, 'Ошибка RAG: $e');
                                        } finally {
                                          setState(() => _isExtractingRag = false);
                                        }
                                      },
                              ),
                              const Spacer(),
                              if (_currentRagSummary != null && _currentRagSummary!.isNotEmpty)
                                IconButton(
                                  tooltip: isRu ? 'Очистить RAG-выжимку' : 'Clear RAG summary',
                                  icon: const Icon(Icons.delete_outline, size: 17, color: Tg.textDim),
                                  splashRadius: 16,
                                  onPressed: () {
                                    setState(() {
                                      _currentRagSummary = null;
                                      _currentRagCount = 0;
                                      _currentRagDate = null;
                                    });
                                    ContactDossierStore.instance.updateRagSummary(widget.chat.id, '', 0);
                                  },
                                ),
                            ],
                          ),

                          // Превью активного RAG-саммари
                          if (_currentRagSummary != null && _currentRagSummary!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C48C).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: const Color(0xFF00C48C).withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF00C48C)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          _currentRagDate != null
                                              ? (isRu
                                                  ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ., в ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})'
                                                  : 'Active RAG summary ($_currentRagCount msgs, at ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})')
                                              : (isRu ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ.)' : 'Active RAG summary ($_currentRagCount msgs)'),
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _currentRagSummary!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // КАРТОЧКА 2: Автокомпрессия и контекстная память диалога
                    Container(
                      padding: const EdgeInsets.all(12),
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
                                  isRu ? 'Автокомпрессия и память контекста' : 'Auto-compression & Context Memory',
                                  style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isRu
                                ? 'Сжимает длинную историю диалога в память при достижении порога, сохраняя свежие реплики сырыми.'
                                : 'Compresses long conversation history into memory upon reaching threshold, keeping recent turns raw.',
                            style: const TextStyle(fontSize: 10.5, color: Tg.textDim, height: 1.25),
                          ),
                          const SizedBox(height: 6),

                          // Тумблер автокомпрессии
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isRu ? 'Автокомпрессия при переполнении:' : 'Auto-compress on threshold:',
                                style: const TextStyle(fontSize: 11.5, color: Tg.text, fontWeight: FontWeight.w400),
                              ),
                              Transform.scale(
                                scale: 0.72,
                                child: Switch.adaptive(
                                  value: _autoCompressEnabled,
                                  activeTrackColor: const Color(0xFF51B2FF).withValues(alpha: 0.35),
                                  activeThumbColor: const Color(0xFF51B2FF),
                                  onChanged: (val) {
                                    setState(() => _autoCompressEnabled = val);
                                  },
                                ),
                              ),
                            ],
                          ),

                          if (_autoCompressEnabled) ...[
                            const SizedBox(height: 4),
                            // Слайдер порога срабатывания
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isRu ? 'Порог срабатывания сжатия:' : 'Compression trigger threshold:',
                                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isRu ? '$_autoCompressThreshold сообщ.' : '$_autoCompressThreshold msgs',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF51B2FF)),
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
                                value: _autoCompressThreshold.toDouble().clamp(10.0, 80.0),
                                min: 10,
                                max: 80,
                                divisions: 14,
                                activeColor: const Color(0xFF51B2FF),
                                inactiveColor: Colors.white.withValues(alpha: 0.08),
                                onChanged: (val) {
                                  setState(() => _autoCompressThreshold = val.round());
                                },
                              ),
                            ),

                            // Слайдер окна свежих сырых сообщений
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isRu ? 'Свежих сообщений без сжатия (окно):' : 'Raw recent window:',
                                  style: const TextStyle(fontSize: 11, color: Tg.textDim),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isRu ? '$_keepRawCount сообщ.' : '$_keepRawCount msgs',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF51B2FF)),
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
                                value: _keepRawCount.toDouble().clamp(3.0, 20.0),
                                min: 3,
                                max: 20,
                                divisions: 17,
                                activeColor: const Color(0xFF51B2FF),
                                inactiveColor: Colors.white.withValues(alpha: 0.08),
                                onChanged: (val) {
                                  setState(() => _keepRawCount = val.round());
                                },
                              ),
                            ),

                            // Призма сжатия диалога
                            const SizedBox(height: 2),
                            Text(
                              isRu ? 'Призма сжатия диалога:' : 'Dialogue compression lens:',
                              style: const TextStyle(fontSize: 11, color: Tg.text, fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Tg.sidebar,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: TextField(
                                controller: _dialogueCompressionController,
                                maxLines: 2,
                                style: const TextStyle(color: Tg.text, fontSize: 11),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: isRu ? 'Инструкция для сжатия диалога...' : 'Compression instructions...',
                                  hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 10.5),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: _isCompressingDialogue
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF51B2FF)))
                                    : const Icon(Icons.archive_outlined, size: 14),
                                label: Text(
                                  _isCompressingDialogue
                                      ? (isRu ? 'Сжатие...' : 'Compressing...')
                                      : (isRu
                                          ? 'Сжать диалог сейчас (${existingSession?.messages.length ?? 0} сообщ.)'
                                          : 'Compress dialogue now (${existingSession?.messages.length ?? 0} msgs)'),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                                onPressed: _isCompressingDialogue
                                    ? null
                                    : () async {
                                        setState(() => _isCompressingDialogue = true);
                                        try {
                                          final compressed = await CopilotSessionStore.instance.compressSessionIntelligent(sessionId);
                                          if (context.mounted) {
                                            if (compressed) {
                                              TgToast.show(context, isRu ? '🗜️ Диалог сжат и сохранен в памяти!' : '🗜️ Dialogue compressed to memory!');
                                            } else {
                                              TgToast.show(
                                                context,
                                                isRu
                                                    ? 'В диалоге мало сообщений (меньше окна $_keepRawCount)'
                                                    : 'Dialogue has fewer messages than window ($_keepRawCount)',
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) TgToast.show(context, 'Ошибка сжатия: $e');
                                        } finally {
                                          setState(() => _isCompressingDialogue = false);
                                        }
                                      },
                              ),
                              const Spacer(),
                              if (existingSession?.contextSummary != null && existingSession!.contextSummary!.isNotEmpty)
                                Text(
                                  isRu ? '⚡ Память: активна' : '⚡ Memory: active',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF00C48C), fontWeight: FontWeight.w500),
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
            const SizedBox(height: 14),

            // Кнопки действий
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openInCopilot,
                  icon: const Icon(Icons.forum_outlined, size: 14),
                  label: Text(
                    isRu ? 'Открыть в Copilot' : 'Open in Copilot',
                    style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF51B2FF),
                    side: BorderSide(color: const Color(0xFF51B2FF).withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isRu ? 'Отмена' : 'Cancel',
                        style: const TextStyle(color: Tg.textDim, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Tg.accentDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Tg.border),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isRu ? 'Сохранить' : 'Save',
                        style: const TextStyle(fontWeight: Tg.fontMedium, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
