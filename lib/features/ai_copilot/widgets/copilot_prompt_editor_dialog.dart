import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_account.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../models/contact_dossier.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';

/// Диалог настройки системных директив, RAG-сбора фактов и автосжатия диалога для сессии Copilot.
class CopilotPromptEditorDialog extends StatefulWidget {
  const CopilotPromptEditorDialog({
    super.key,
    required this.session,
    this.onSaved,
  });

  final CopilotSession session;
  final VoidCallback? onSaved;

  static void show(
    BuildContext context, {
    required CopilotSession session,
    VoidCallback? onSaved,
  }) {
    showDialog(
      context: context,
      builder: (_) => CopilotPromptEditorDialog(
        session: session,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CopilotPromptEditorDialog> createState() => _CopilotPromptEditorDialogState();
}

class _CopilotPromptEditorDialogState extends State<CopilotPromptEditorDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _ragPromptController;
  late final TextEditingController _dialogueCompressionController;

  late final bool _isContact;
  late final String? _chatId;
  late final ContactDossier? _dossier;

  late int _messageLimit;
  late bool _autoCompressEnabled;
  late int _autoCompressThreshold;
  late int _keepRawCount;

  String? _currentRagSummary;
  int _currentRagCount = 0;
  DateTime? _currentRagDate;

  bool _isExtractingRag = false;
  bool _isCompressingDialogue = false;

  TgChat? _targetChat;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _controller = TextEditingController(text: session.systemPrompt);
    _isContact = session.id.startsWith('contact_');
    _chatId = _isContact ? session.id.replaceFirst('contact_', '') : null;
    _dossier = _chatId != null ? ContactDossierStore.instance.getDossier(_chatId).value : null;

    _messageLimit = session.messageLimit > 0
        ? session.messageLimit
        : (_dossier != null && _dossier.analysisMessageLimit > 0 ? _dossier.analysisMessageLimit : 30);

    _ragPromptController = TextEditingController(
      text: session.ragPrompt.isNotEmpty
          ? session.ragPrompt
          : (_dossier?.ragPrompt ?? CopilotSession.defaultRagPrompt),
    );

    _dialogueCompressionController = TextEditingController(
      text: session.dialogueCompressionPrompt.isNotEmpty
          ? session.dialogueCompressionPrompt
          : CopilotSession.defaultDialogueCompressionPrompt,
    );

    _autoCompressEnabled = session.autoCompressEnabled;
    _autoCompressThreshold = session.autoCompressThreshold;
    _keepRawCount = session.keepRawCount;

    _currentRagSummary = session.ragFactSummary ?? _dossier?.ragFactSummary;
    _currentRagCount = session.ragFactSummaryCount > 0
        ? session.ragFactSummaryCount
        : (_dossier?.ragFactSummaryCount ?? 0);
    _currentRagDate = session.ragFactUpdatedAt ?? _dossier?.ragFactUpdatedAt;

    // Поиск целевого чата для RAG-экстракции
    final currentAcc = AccountManager.instance.currentAccount.value;
    final allChats = [
      ...TdlibService.instance.chats.value,
      ...AccountManager.instance.getChats(currentAcc.id),
    ];
    if (_chatId != null) {
      final found = allChats.where((c) => c.id == _chatId).toList();
      if (found.isNotEmpty) _targetChat = found.first;
    }
    if (_targetChat == null) {
      final activeId = AppState.selectedChatId.value;
      final found = allChats.where((c) => c.id == activeId).toList();
      if (found.isNotEmpty) _targetChat = found.first;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ragPromptController.dispose();
    _dialogueCompressionController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text;
    final ragPrompt = _ragPromptController.text;
    final dialoguePrompt = _dialogueCompressionController.text;

    CopilotSessionStore.instance.updateSessionPrompt(widget.session.id, text);
    CopilotSessionStore.instance.updateSessionMessageLimit(widget.session.id, _messageLimit);
    CopilotSessionStore.instance.updateSessionRagConfig(
      widget.session.id,
      prompt: ragPrompt,
      summary: _currentRagSummary,
      count: _currentRagCount,
    );
    CopilotSessionStore.instance.updateSessionCompressionConfig(
      widget.session.id,
      enabled: _autoCompressEnabled,
      threshold: _autoCompressThreshold,
      keepRaw: _keepRawCount,
      prompt: dialoguePrompt,
    );

    if (_chatId != null) {
      ContactDossierStore.instance.updateSystemPrompt(_chatId, text);
      ContactDossierStore.instance.updateAnalysisMessageLimit(_chatId, _messageLimit);
      ContactDossierStore.instance.updateRagPrompt(_chatId, ragPrompt);
      if (_currentRagSummary != null) {
        ContactDossierStore.instance.updateRagSummary(_chatId, _currentRagSummary!, _currentRagCount);
      }
    }
    Navigator.of(context).pop();
    TgToast.show(context, tr('directives_updated_toast'));
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isRu = I18n.instance.isRu;

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
                  controller: _controller,
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
                        if (_targetChat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _targetChat!.title,
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
                        Expanded(
                          child: Text(
                            isRu ? 'Глубина сбора фактов (RAG):' : 'Fact extraction depth (RAG):',
                            style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF51B2FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRu ? '$_messageLimit сообщ.' : '$_messageLimit msgs',
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
                        value: _messageLimit.toDouble().clamp(10.0, 500.0),
                        min: 10,
                        max: 500,
                        divisions: 49,
                        activeColor: const Color(0xFF51B2FF),
                        inactiveColor: Colors.white.withValues(alpha: 0.1),
                        onChanged: (val) {
                          setState(() => _messageLimit = val.round());
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
                        controller: _ragPromptController,
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
                          icon: _isExtractingRag
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF51B2FF)))
                              : const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            _isExtractingRag
                                ? (isRu ? 'Сбор фактов...' : 'Extracting...')
                                : (isRu ? 'Собрать RAG-выжимку ($_messageLimit сообщ.)' : 'Extract RAG Facts ($_messageLimit msgs)'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _isExtractingRag || _targetChat == null
                              ? null
                              : () async {
                                  final chat = _targetChat;
                                  if (chat == null) return;
                                  setState(() => _isExtractingRag = true);
                                  try {
                                    final realHistory = TdlibService.instance.messagesOf(chat.id).value;
                                    final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : chat.messages;
                                    final summary = await CopilotSessionStore.instance.runRagFactExtraction(
                                      sessionId: session.id,
                                      chatId: chat.id,
                                      messages: msgs,
                                      limit: _messageLimit,
                                      ragPrompt: _ragPromptController.text,
                                      chatTitle: chat.title,
                                    );
                                    setState(() {
                                      _currentRagSummary = summary;
                                      _currentRagCount = msgs.length > _messageLimit ? _messageLimit : msgs.length;
                                      _currentRagDate = DateTime.now();
                                    });
                                    if (context.mounted) {
                                      TgToast.show(context, isRu ? '⚡ RAG-выжимка из $_currentRagCount сообщений собрана!' : '⚡ RAG summary extracted!');
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
                            icon: const Icon(Icons.delete_outline, size: 18, color: Tg.textDim),
                            onPressed: () {
                              setState(() {
                                _currentRagSummary = null;
                                _currentRagCount = 0;
                                _currentRagDate = null;
                              });
                            },
                          ),
                      ],
                    ),

                    // Превью активного RAG-саммари
                    if (_currentRagSummary != null && _currentRagSummary!.isNotEmpty) ...[
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
                                    _currentRagDate != null
                                        ? (isRu
                                            ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ., в ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})'
                                            : 'Active RAG summary ($_currentRagCount msgs, at ${_currentRagDate!.hour.toString().padLeft(2, "0")}:${_currentRagDate!.minute.toString().padLeft(2, "0")})')
                                        : (isRu ? 'RAG-выжимка активна (сжато $_currentRagCount сообщ.)' : 'Active RAG summary ($_currentRagCount msgs)'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00C48C)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentRagSummary!,
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
                      const SizedBox(height: 6),
                      // Слайдер порога срабатывания
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isRu ? 'Порог срабатывания сжатия:' : 'Compression trigger threshold:',
                              style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRu ? '$_autoCompressThreshold сообщ.' : '$_autoCompressThreshold msgs',
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
                          Expanded(
                            child: Text(
                              isRu ? 'Свежих сообщений без сжатия (окно):' : 'Raw recent window:',
                              style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF51B2FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRu ? '$_keepRawCount сообщ.' : '$_keepRawCount msgs',
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
                          controller: _dialogueCompressionController,
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
                          icon: _isCompressingDialogue
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF51B2FF)))
                              : const Icon(Icons.archive_outlined, size: 14),
                          label: Text(
                            _isCompressingDialogue
                                ? (isRu ? 'Сжатие...' : 'Compressing...')
                                : (isRu ? 'Сжать диалог сейчас (${session.messages.length} сообщ.)' : 'Compress dialogue now (${session.messages.length} msgs)'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          onPressed: _isCompressingDialogue
                              ? null
                              : () async {
                                  setState(() => _isCompressingDialogue = true);
                                  try {
                                    final compressed = await CopilotSessionStore.instance.compressSessionIntelligent(session.id);
                                    if (context.mounted) {
                                      if (compressed) {
                                        TgToast.show(context, isRu ? '🗜️ Диалог сжат и сохранен в памяти!' : '🗜️ Dialogue compressed to memory!');
                                      } else {
                                        TgToast.show(context, isRu ? 'В диалоге мало сообщений (меньше окна $_keepRawCount)' : 'Dialogue has fewer messages than window ($_keepRawCount)');
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
          onPressed: _save,
          child: Text(tr('save')),
        ),
      ],
    );
  }
}
