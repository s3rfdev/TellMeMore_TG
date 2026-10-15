import 'package:flutter/material.dart';

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
import '../services/copilot_session_store.dart';

/// Экран активного чата с выбранным Copilot-агентом.
class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _summaryExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(CopilotSession session, String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _controller.clear();
    final userMsg = CopilotMessage(text: query, isUser: true);

    setState(() {
      _isLoading = true;
    });

    CopilotSessionStore.instance.addMessage(session.id, userMsg);
    _scrollToBottom();

    // Проверка автокомпрессии до запроса
    final settings = AiSettingsStore.instance.settings.value;
    final compressedBefore = CopilotSessionStore.instance.checkAndAutoCompress(session.id, settings);
    final isRu = I18n.instance.isRu;
    if (compressedBefore && mounted) {
      TgToast.show(
        context,
        isRu
            ? '🗜️ Автокомпрессия сработала: контекст сжат по объёму'
            : '🗜️ Auto-compression triggered: context compressed',
      );
    }

    await Future.delayed(const Duration(milliseconds: 1100));
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
      final realHistory = TdlibService.instance.messagesOf(matchedChat.id).value;
      final msgs = realHistory.messages.isNotEmpty ? realHistory.messages : matchedChat.messages;

      tool = 'tdlib.inspectChat(chat: "${matchedChat.title}", limit: ${msgs.length})';
      output = isRu
          ? 'Изучена переписка: ${msgs.length} сообщ. из чата «${matchedChat.title}»'
          : 'Inspected ${msgs.length} messages from "${matchedChat.title}"';

      final lastIncoming = msgs.where((m) => !m.outgoing).firstOrNull ?? (msgs.isNotEmpty ? msgs.first : null);

      if (lower.contains('ответь') ||
          lower.contains('напиши') ||
          lower.contains('составь ответ') ||
          lower.contains('предложи ответ') ||
          lower.contains('reply') ||
          lower.contains('draft')) {
        final snippet = lastIncoming != null
            ? (isRu ? 'в ответ на «${lastIncoming.text}»' : 'in reply to "${lastIncoming.text}"')
            : (isRu ? 'для отправки в чат' : 'for the chat');

        reply = isRu
            ? '💡 **Предлагаемый вариант ответа для «${matchedChat.title}»** ($snippet):\n\n'
                '«Здравствуйте! ${effectivePrompt.isNotEmpty ? "Учитывая установленные договоренности: " : ""}'
                'Предлагаю зафиксировать следующие шаги и свериться по деталям.»\n\n'
                '${effectivePrompt.isNotEmpty ? "🎯 *Директивы*: ответ составлен согласно системному промпту." : "🎯 *Подсказка*: вы можете настроить точные директивы в системном промпте чата."}'
            : '💡 **Suggested reply for "${matchedChat.title}"** ($snippet):\n\n'
                '«Hello! ${effectivePrompt.isNotEmpty ? "Taking into account our arrangements: " : ""}'
                'I suggest we confirm the next steps and align on details.»\n\n'
                '${effectivePrompt.isNotEmpty ? "🎯 *Directives*: response crafted according to system prompt." : "🎯 *Tip*: you can configure custom response directives in the chat system prompt."}';
      } else if (lower.contains('саммари') ||
          lower.contains('изучи') ||
          lower.contains('проанализируй') ||
          lower.contains('выжимк') ||
          lower.contains('summary') ||
          lower.contains('analyze')) {
        final sb = StringBuffer();
        if (isRu) {
          sb.writeln('📋 **Анализ чата «${matchedChat.title}»** (изучено ${msgs.length} сообщений):');
          if (msgs.isEmpty) {
            sb.writeln('• История переписки пуста.');
          } else {
            if (lastIncoming != null) {
              sb.writeln('• **Последнее сообщение**: «${lastIncoming.text}» (${lastIncoming.time})');
            }
            sb.writeln('• **Сообщений в ленте**: ${msgs.length} (исходящих: ${msgs.where((m) => m.outgoing).length}, входящих: ${msgs.where((m) => !m.outgoing).length})');
            final sampleTexts = msgs.take(4).map((m) => '«${m.text.replaceAll("\n", " ")}»').join(', ');
            sb.writeln('• **Темы и ключевой контекст**: $sampleTexts');
            if (effectivePrompt.isNotEmpty) {
              sb.writeln('• **Системные директивы**: $effectivePrompt');
            }
          }
        } else {
          sb.writeln('📋 **Analysis of "${matchedChat.title}"** (analyzed ${msgs.length} messages):');
          if (msgs.isEmpty) {
            sb.writeln('• Conversation is empty.');
          } else {
            if (lastIncoming != null) {
              sb.writeln('• **Last message**: "${lastIncoming.text}" (${lastIncoming.time})');
            }
            sb.writeln('• **Messages in feed**: ${msgs.length} (outgoing: ${msgs.where((m) => m.outgoing).length}, incoming: ${msgs.where((m) => !m.outgoing).length})');
            final sampleTexts = msgs.take(4).map((m) => '"${m.text.replaceAll("\n", " ")}"').join(', ');
            sb.writeln('• **Topics & context**: $sampleTexts');
            if (effectivePrompt.isNotEmpty) {
              sb.writeln('• **System directives**: $effectivePrompt');
            }
          }
        }
        reply = sb.toString();
      } else {
        reply = isRu
            ? 'Принял задачу по чату **${matchedChat.title}**: "$query".\n\n'
                '${effectivePrompt.isNotEmpty ? "Действую по системному промпту: *$effectivePrompt*.\n\n" : ""}'
                'Изучил историю сообщений. Что конкретно подготовить: сформулировать ответ собеседнику или сделать саммари?'
            : 'Received task for **${matchedChat.title}**: "$query".\n\n'
                '${effectivePrompt.isNotEmpty ? "Operating per system prompt: *$effectivePrompt*.\n\n" : ""}'
                'Reviewed message history. What shall I prepare: formulate a response or generate a summary?';
      }
    } else {
      reply = isRu
          ? 'Принял задачу: "$query".\n\n'
              '${effectivePrompt.isNotEmpty ? "Действую строго по директивам агента: *$effectivePrompt*.\n\n" : ""}'
              'Роль агента: **${session.agentRole}**. Если нужно изучить конкретный чат, назови его имя (например: «изучи переписку с Тарасом») или открой системный промпт в настройках чата.'
          : 'Task received: "$query".\n\n'
              '${effectivePrompt.isNotEmpty ? "Operating strictly under directives: *$effectivePrompt*.\n\n" : ""}'
              'Agent role: **${session.agentRole}**. If you want me to inspect a specific chat, mention its name (e.g. "analyze chat with Taras") or open the system prompt in chat settings.';
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Tg.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Row(
            children: [
              Icon(session.avatarIcon, color: session.avatarColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('agent_directives_title', {'role': session.agentRole}),
                  style: const TextStyle(color: Tg.text, fontSize: 15),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('system_prompt_desc'),
                  style: const TextStyle(color: Tg.textDim, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Tg.field,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    style: const TextStyle(color: Tg.text, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: tr('agent_directives_hint'),
                      hintStyle: const TextStyle(color: Tg.textFaint),
                    ),
                  ),
                ),
              ],
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
              ),
              onPressed: () {
                CopilotSessionStore.instance.updateSessionPrompt(session.id, controller.text);
                Navigator.of(context).pop();
                TgToast.show(context, tr('directives_updated_toast'));
              },
              child: Text(tr('save')),
            ),
          ],
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
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Row(
            children: [
              const Icon(Icons.layers_outlined, color: Color(0xFF8774E1), size: 22),
              const SizedBox(width: 10),
              Text(
                tr('context_sandwich_title'),
                style: const TextStyle(color: Tg.text, fontSize: 16, fontWeight: FontWeight.w600),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
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
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
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
                      color: session.contextSummary != null ? const Color(0xFF00C48C) : const Color(0xFF8774E1),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${session.totalTokens} tok',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

    if (role.contains('hunter') || role.contains('ваканси') || role.contains('лид')) {
      actions = [
        '💼 Вакансии Flutter Remote',
        '🔍 Спарсить чат заказов',
        '📋 Подготовить отклик',
        '🎯 Фильтр по рейту от \$4000',
      ];
    } else if (role.contains('crm') || role.contains('анали')) {
      actions = [
        '📊 Саммари переписки с Тарасом',
        '🎯 Досье контакта',
        '⏳ Зафиксировать договоренности',
        '📝 Экспорт в CRM заметки',
      ];
    } else if (role.contains('code') || role.contains('архитект')) {
      actions = [
        '🛠️ Ревью Isolate C++ в TDLib',
        '⚡ Анализ задержки звонков',
        '🧪 Написать unit-тесты',
        '📦 Проверить сжатие контекста',
      ];
    } else {
      actions = [
        '💼 Найти вакансии Flutter',
        '📊 Саммари чатов',
        '🔍 Спарсить группу Недвижимость',
        '🎯 Пробить профиль по Шерлоку',
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

  Widget _buildInputBar(CopilotSession session) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
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
    );
  }
}
