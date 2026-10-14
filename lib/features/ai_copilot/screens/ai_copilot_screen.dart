import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/tg_toast.dart';
import '../models/ai_settings_model.dart';

class CopilotMessage {
  CopilotMessage({
    required this.text,
    required this.isUser,
    this.toolName,
    this.toolOutput,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final String text;
  final bool isUser;
  final String? toolName;
  final String? toolOutput;
  final DateTime time;
}

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<CopilotMessage> _messages = [
    CopilotMessage(
      text: 'Привет! Я твой автономный AI Copilot для Telegram.\n'
          'Я умею искать вакансии и целевые лиды в группах, парсить чаты, суммировать переписки и генерировать персональные ответы с учетом CRM-досье собеседников.',
      isUser: false,
    ),
    CopilotMessage(
      text: 'Спарси последние предложения о работе по Flutter из открытых каналов',
      isUser: true,
    ),
    CopilotMessage(
      text: 'Выполнил поиск по публичным каналам через TDLib. Вот последние актуальные варианты:',
      isUser: false,
      toolName: 'tdlib.searchPublicChats("flutter jobs remote")',
      toolOutput: 'Найдено 4 релевантных канала, просканировано 120 сообщений',
    ),
    CopilotMessage(
      text: '1. **Senior Flutter Architect** (Remote, \$5000-\$7000)\n'
          '   • Проект: FinTech / Crypto кошелек\n'
          '   • Стек: Flutter, BLoC, FFI, WebRTC, Native C++\n'
          '   • Контакт: @crypto_fin_hr\n\n'
          '2. **Flutter / Dart Engineer (AI Apps)** (Remote / Бали, \$4000+)\n'
          '   • Проект: Desktop & Mobile клиент с интеграцией локальных LLM\n'
          '   • Контакт: @asmirnov_ai\n\n'
          'Подготовить отклик с учетом твоего профиля и опыта работы с TDLib?',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(CopilotMessage(text: query, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    String reply;
    String? tool;
    String? output;

    final lower = query.toLowerCase();
    if (lower.contains('ваканси') || lower.contains('работ')) {
      tool = 'tdlib.searchMessages("flutter вакансия remote")';
      output = 'Сканирование 35 сообщений в @flutter_jobs_channel';
      reply = 'Нашел 2 новых предложения за последние 24 часа! Подходит под стек Flutter Desktop/Linux.';
    } else if (lower.contains('саммари') || lower.contains('переписк')) {
      tool = 'tdlib.getChatHistory(chatId: "taras", limit: 30)';
      output = 'История чата получена и сжата через LLM Context Engine';
      reply = '📌 **Краткое саммари переписки с Тарасом:**\n'
          '• Обсуждали проект Telegram клиента с LLM и Шерлоком на аватарах.\n'
          '• Договорились о тестировании Claude и китайских моделей.\n'
          '• Следующий шаг: оформление открытого репозитория на GitHub.';
    } else if (lower.contains('спарс') || lower.contains('групп')) {
      tool = 'tdlib.getSupergroupMembers(supergroupId: "nha-trang-estate")';
      output = 'Спарсено 150 активных участников группы';
      reply = 'Спарсил участников чата недвижимости. Найдено 14 агентов и 8 потенциальных арендаторов. Добавить их в контакты?';
    } else {
      reply = 'Понял задачу: "$query". Анализирую данные Telegram и готовлю решение с текущей моделью.';
    }

    setState(() {
      _messages.add(CopilotMessage(
        text: reply,
        isUser: false,
        toolName: tool,
        toolOutput: output,
      ));
      _isLoading = false;
    });

    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(),
          _buildQuickActionCards(),
          Expanded(child: _buildMessagesList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF8774E1), Color(0xFF51B2FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'AI Copilot & TDLib Agent',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Tg.text,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.verified, size: 14, color: Color(0xFF8774E1)),
                  ],
                ),
                ValueListenableBuilder<AiSettings>(
                  valueListenable: AiSettingsStore.instance.settings,
                  builder: (context, s, _) {
                    return Text(
                      '${s.provider} • ${s.model} (Автономный агент)',
                      style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
                    );
                  },
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.delete_sweep_outlined,
            iconSize: 20,
            color: Tg.textDim,
            onTap: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  CopilotMessage(
                    text: 'История диалога с Copilot очищена. Чем могу помочь?',
                    isUser: false,
                  ),
                );
              });
              TgToast.show(context, 'Сессия Copilot очищена');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards() {
    final actions = [
      '💼 Найти вакансии Flutter',
      '📊 Саммари переписки с Тарасом',
      '🔍 Спарсить группу Недвижимость',
      '🎯 Пробить профиль по Шерлоку',
    ];

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
            onPressed: () => _sendMessage(action),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(CopilotMessage msg) {
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
                  const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF8774E1)),
                  const SizedBox(width: 6),
                  const Text(
                    'AI Copilot',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8774E1),
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
            SelectableText(
              msg.text,
              style: const TextStyle(fontSize: 13.5, color: Tg.text, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
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
              onSubmitted: _sendMessage,
              style: const TextStyle(fontSize: 14, color: Tg.text),
              decoration: const InputDecoration(
                hintText: 'Спросите Copilot или дайте команду для Telegram…',
                hintStyle: TextStyle(fontSize: 14, color: Tg.textFaint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF8774E1),
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
